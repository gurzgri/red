# ODBC-Scheme
odbc:// scheme for Red and Red/System

The Red ODBC scheme allows easy access to databases and datasources
supporting ODBC.

The scheme supports SQL statements SELECT and INSERT, UPDATE and
DELETE as well as catalog functions. It supports statement parameters and
is Unicode aware. It supports prepared execution of statements,
batched statements, parameter arrays and cursors.

The ODBC scheme is currently available only for the Windows platform, other
platforms may follow.

# Usage
Because the binding is partly written in Red/System, interpreted scripts using
it need to either be run from a console compiled with ODBC.

To use the scheme interactively, compile the CLI or GUI console with a
`Needs: 'ODBC` header. Same goes for your own scripts you want to compile.

# Drivers and Datasources

You can retrieve information on installed ODBC drivers with the function
`drivers` located at

```Red
system/schemes/odbc/state/drivers
```

It returns a block of descriptions and attribute maps.

Information on configured system and user ODBC datasources can be retrieved
with the `sources` function

```Red
system/schemes/odbc/state/sources
```

It returns a block of datasource name and description strings.

# Connections and Statements

## Opening Connections
If a datasource "database" has been set up in the systems ODBC panel,
you connect to it with `open`:

```Red
connection: open odbc://database
```

Or connect using a target connection string tailored to the specific
requirements of the database you are using:

```Red
connection: open make port! [
    scheme: 'odbc
    target: "driver={<DRIVERNAME>};server=<IPADDRESS>;port=<PORT>;database=<DATABASE>;uid=<USER>;pwd=<PASS>"
]
```

By default, opening connections won't timeout, but a timeout in
seconds can be configured with

```Red
system/schemes/odbc/state/timeout: 15
```

*before* opening the connection port.

## Opening Statements
Before you can execute a SQL statement, you need to acquire a statement with `open` applied to the previously opened connection:

```Red
statement: open connection
```

You may allocate multiple statements on the same database connection:

```Red
customers: open connection
products:  open connection
orders:    open connection
```

There are benefits in using multiple statements for specialised purposes
depending on your usage pattern (see the section on statement preparation
for further information).

## Closing Statements and Connections
Once you're done with a statement, close it with `close` as in

```Red
close statement
```

Closing a connection will automatically close all associated statements, so it is often sufficient to instead just close the connection itself:

```Red
close connection
```

# Executing SQL Statements

## Inserting Statements, Retrieving Results
The following example should give you an (informal) idea on how SQL statements are
executed.

You execute a SQL statement with `insert`:

```Red
insert statement "INSERT INTO Languages (Name) VALUES ('Red')"
== 1
```

For row-changing INSERT, UPDATE and DELETE statements like the one above,
`insert` will simply return the number of rows affected.

For result-set generating statements, the number of rows can be retrieved with
`length?`.

```Red
insert fairytales "SELECT Name FROM Dwarves"
length? fairytales ;== 7
```

`insert` itself applied on result-set SQL statement instead returns the column
names as a block of Red words:

```Red
insert statement "SELECT * FROM Film"
== [id category description length playing-now rating tickets-sold title]
```

To retrieve the actual rows of the result-set use `copy`:

```Red
copy statement
== [
    [1 1 {A post-modern excursion into family dynamics and Thai cuisine.} 130 true "PG-13" 47000 "ÄÖÜßäöü"]
    [2 1 "A gripping true story of honor and discovery" 122 true "R" 50000 "A Kung Fu Hangman1"]
    ...
```

By default, executing statements won't timeout, but a timeout can be set in
seconds (integer!), as time! or as none! with

```Red
change statement [timeout: 0:02]        ;-- or statement/state/timeout: 120
```


### More Examples

A parametrized SELECT statement:

```Red
insert statement ["SELECT * FROM Film WHERE Id = ?" 6]
== [id category description length playing-now rating tickets-sold title]
copy statement
== [[6 2 "A heart-warming tale of friendship" 91 true "G" 7500 "Gangs of New York"]]
```

An INSERT statement inserting one row:

```Red
insert statement ["INSERT INTO Person (LastName, Age) VALUES (?, ?)" name age]
== 1
```

An UPDATE statement updating no rows at all:

```Red
insert statement ["UPDATE Person SET LastName = ? WHERE IsActive = ?" "(deleted)" no]
== 0
```

A DELETE statement deleting five rows:

```Red
insert statement ["DELETE FROM RGB_Color WHERE Blue <= ?" 127]
== 5
```

## Retrieving Rows

After executing a SELECT query, a simple `copy` on the statement is all you
need to retrieve all rows selected:

```Red
insert statement ["SELECT * FROM Earthlings WHERE Country = ?" "Vatikan City"]
length? statement               ;== 618
copy statement                  ;== [... (618 rows)]
```

However, most ODBC drivers won't fetch that data one row at a time or in only
one, possibly huge, request to the datasource. They rather fetch only a
predefined number of rows in what is called a ***row set***, hand that over to
the calling application and wait for it to ask for the next row set. That way,
both network traffic can be drastically reduced and at the same time the
calling application doesn't have to wait until all rows have been transferred.

`copy` *does* abstract that away from you, it fetches all rowsets one after
another and only then hands you out the complete ***result set***.

That often comes in very handy. But it isn't suited very well to retrieve huge
results as in e.g.

```Red
insert statement ["SELECT * FROM earthlings WHERE country = ?" "USA"]
length? statement               ;== 331'449'281
us-citiziens: copy statement    ;-- Red might not able to process that amount of data ...
```

For large result sets, it is often more practical to only retrieve a single row
set with `next` as in

```Red
until [
    rowset: next statement
    somehow-process rowset
    tail? statement
]
```

or

```Red
while [not empty? rowset: next statement] [
    somehow-process rowset
]
```

To get the most out of that approach, set `statement/state/window` to the number of rows that will best suit your needs:

```Red
change statement [window: 1'000]
insert statement ["SELECT * FROM earthlings WHERE country = ?" "USA"]
```

It *is* possible to change the window size between two fetches with `next`.

And as a shortcut to setting the rowset window before executing a statement, there `insert/part`:

```Red
insert/part statement ["SELECT * FROM earthlings WHERE country = ?" "USA"] 1'000
```


Finally, note that a `copy` following one or more `next`s won't return the
complete result set, but will only return the rows of the remaining rowsets in
the result set.

## Blocked and flat row retrieval

By default, each row of a rowset will be returned in its own block. That is
often very convenient, but it's not the optimal solution when handling large
volumnes of data.

To retrieve results in flat fashion, on scheme, connection or statement level set

```Red
system/schemes/odbc/state/flat?: true
```
```Red
change connection [flat?: true]
```
```Red
change statement  [flat?: true]
```

On statement, connection and scheme level, `flat?` may be set to `true` or `false`. On statement and connection level it
can also be set to `none` to delegate the decision from the statement to the connection and from the connection to the scheme.

## Positioning the Current Rowset ("Paging")

Instead of retrieving a result set as a whole with `copy` (all rows),
it can be retrieved in parts with `next` (first rowset if no rowset has been fetched before, next rowset otherwise).

Provided the datasource you connect to allows it, with
```Red
change statement [access: 'static]    ;-- or 'dynamic
```
prior to executing it with `insert`, you can move back and
forth to arbitrary rowsets in the result set with `head` (first rowset), `back` (previous rowset)
and `tail` (last rowset), too.

Additionally, you can do *relative* movements with `skip` and *absolute* movements with `at`.


```Red
rowets: head statement
rowset: next statement
rowset: back statement
rowset: tail statement
```
```Red
rowset:   at statement <position>
rowset: skip statement <offset>
```

To check for the current position of the rowset in the result set, use `head?`, `tail?` and `index?`:

```Red
 head? statement
 tail? statement
index? statement
```

Note however that due to the way in which ODBC implements result sets, the
semantics and behaviour of these functions somewhat differs from the usual
behaviour with "normal" series in Red.

The following restrictions apply:

* You can't use `head?`, `tail?` and `index?` prior to fetching at least one
rowset with `head`, `next`, `back`, `tail` (or `copy`).
* `next` and `back` don't move by rows, but rather move by rowsets. Hence,
think "paging" here.
* `next` after retrieval of the *(n-1)th* rowset of *r* rows might return less
than *r* rows if the total number of rows in the result set cannot be divided
by *r* without a remainder.
* `tail` however will always return the last rowset of *r* rows (if the result
set consists of at least *r* rows, that is).
* `tail` especially ***does not*** position the statement "after the last row",
as it does with series.
* `back` on a statement positioned at a row number greater than 1 and
lesser-or-equal than *r* will return a rowset of *r* rows, starting with row 1.
In other words, it will "overlap" the previous rowset.

## Positioning the Current Row with a Cursor

You can open a cursor on a statement to move from row to row  in the current rowset:

```Red
cursor: open statement
```

> **Hint:** Most of the time you won't need cursors at all.<p>
> Cursors only come into play when you work with rowsets
> of size > 1 (i.e. when `statement/state/window > 1`) together
> with BLOB and CLOB columns too big to account for their
> maximal size with `statement/state/limit`.<p>
> In these cases a cursor can be positioned on a particlular
> row and BLOBs and CLOBs can then be `pick`ed from there.

Right after fetching a rowset, the cursor will be positioned before the first row in this rowset.

Move it to a particular row with

```Red
head cursor     ;-- first row in rowset
next cursor     ;-- next      -"-
back cursor     ;-- prev      -"-
tail cursor     ;-- last      -"-
```
```Red
  at cursor <position>
skip cursor <offset>
```
To check for the current position in the rowset, use `head?`, `tail?` and `index?` on the cursor:

```Red
 head? cursor
 tail? cursor
index? cursor
```

Note however, that you can't move to a row *outside* of the current rowset. For that you'll have to advance the rowset itself on the statement as described in the previous section.


## BLOB and CLOB Columns

Sometimes you'll have to deal with BLOB and CLOB columns (binary/character large objects) for things like e.g. image data and documents.

Such columns are fetched too, but due to their size chances are that they'll be fetched only *partially* because it wasn't
possible to allocate a buffer big enough for them in advance.

How many 'preview' bytes of a BLOB and how many characters of a CLOB
are retrieved, can be configured with

```Red
change statement [limit: 8096]    ;-- only first 8096 bytes/chars
```

To retrieve BLOBs/CLOBs above that limit, instead of the default way

```Red
photos: open album: open odbc://album
select photos "SELECT FileName, Image, Thumbnail FROM Photos"
== [file-name image thumbnail]
images: next photos
== [
   ["Me at the beach.jpg" #{FFD8FFE0...} #{FFD8FFE0...}]
   ["Me in the snow.jpg"  #{FFD8FFE0...} #{FFD8FFE0...}]
   ["Me in the woods.jpg" #{FFD8FFE0...} #{FFD8FFE0...}]
   ...
```

you'll have to `pick` each single value individually:

```Red
photos: open album: open odbc://album [access: 'static]
change photos [access: 'static window: 100]
cursor: open photos
select photos "SELECT FileName, Image, Thumbnail FROM Photos"
== [file-name image thumbnail]
images: next photos
== [
   ["Me at the beach.jpg" #{FFD8FFE0...} #{FFD8FFE0...}]
   ["Me in the snow.jpg"  #{FFD8FFE0...} #{FFD8FFE0...}]
   ["Me in the woods.jpg" #{FFD8FFE0...} #{FFD8FFE0...}]
   ...
]
at cursor 47
image: pick cursor 'image
== #{
FFD8FFE000104A46494600010101004800480000FFE11B764578696600004D4D
002A00000008000D010F000200000006000000AA0110000200000009000000B0
01120003000000010003...
thumbnail: pick cursor 'thumbnail
== #{
FFD8FFE000104A46494600010101004800480000FFE119584578696600004D4D
002A00000008000D010F000200000006000000AA0110000200000009000000B0
01120003000000010008...
```

You can only `pick` from BLOB/CLOB columns and due to ODBC restrictions the rowset containing the row has to be fetched first.

After that, you can `pick` the desired BLOB or CLOB column by either the column word, column name string or column number.

Depending on the datasource you connect to, if there is more than one BLOB/CLOB column in the result set retrieved,
you have to pick them from left to right due to restrictions ODBC imposes.

That means that in the example above you can not first
`pick cursor 'thumbnail` and then `pick cursor 'image`
from the same column. But you are not required to fetch *all* BLOB/CLOB columns, you can leave out BLOBs/CLOBs you're not interested in.

The values returned will always be of either type `string!` or of type `binary!`.

> As a shortcut to the above, if you work with window/rowset size 1 as in
> ```Red
> change photos [window: 1]
> ```
> you won't need an explicitly `open`ed cursor. You can
> then `pick` directly from the statement as in
> ```Red
> pick photos 'image
> pick photos 'thumbnail
> ```
> instead .




## Deleting Rows with Cursors

The first row of the last-fetched rowset is the ***current row***. `remove` on
a statement will delete the current row in your datasource:

```Red
insert statement "SELECT * FROM Sweets WHERE Sugar = 'Too much'"
remove statement                    ;-- deletes first row in result set
```

NOTE: Not implemented yet!

# Batched Statements

Given that a datasource and its OBDC driver supports it, a SQL string might
contain more than one statement. Executing such a statement will then result
in multiple ***result sets***.

After `insert`ing such a statement, the aforementioned `copy`, `next`, ... port
actions will operate on the first result set only.

To move forward to the next result set, use `update` on the statement.

Just as `insert` does for the first result set, `update` will then return
* the number of affected rows for row changing INSERT, UPDATE and DELETE
statements or
* the columns of a SELECT statement.

If there is no further result set, `update` will return `none`.

NOTE 1: After `update`ing a statement to a next result set, there is no way to
go back a prior result set. There too is no way to know in advance how many
result sets are available. Looping until `update` yields `none` therefor is the
way to go.

NOTE 2: Not all datasources/drivers will return multiple row counts and/or
result sets for row changing statements and might collapse them into a row
count for the entire batch and might collapse the results of a set-generating
statement with an array of parameters into only one result set. To know how
your database connection handles these check the following info in the
connection state:

```Red
connection/state/info/"batch-row-count"        ;-- any of 'procedures, 'explicit and 'rolled-up
connection/state/info/"batch-support"          ;-- any of 'select-explicit, 'row-count-explicit,
                                               ;   'select-proc and 'row-count-proc
connection/state/info/"param-array-row-counts" ;-- either 'batch or 'no-batch
connection/state/info/"param-array-selects"    ;-- one of 'batch, 'no-batch or 'no-select
```

For further reference, see [Microsoft SQL Docs: Multiple Results](https://docs.microsoft.com/en-us/sql/odbc/reference/develop-app/multiple-results?view=sql-server-ver15).

# Statement Parameters
As you have seen already, statement parameters are supported. To use them,
instead of just supplying a statement string supply a block to `insert`.
The statement string has to be the first item in the block. Parameter values
follow as applicable:

```Red
insert statement ["SELECT Column FROM Table WHERE Id BETWEEN ? AND ?" 6 10]
```

Note that the block supplied will be reduced automatically:

```Red
set [lower upper] [6 10]
insert statement [
    "SELECT Column FROM Table WHERE Id BETWEEN ? AND ?"
    lower upper
]
```

The datatypes supported as parameters so far are:

- any-string!
- integer!
- logic!
- float!
- date! (with or without time!)
- time! (no fractions of seconds)
- binary!

## Parameter Arrays

So far we've already seen statements with parameters as in

```Red
insert snowwhite ["INSERT INTO Dwarves (Num, Name) VALUES (?, ?)" 1 "Dopey"]
```

That's nice and all, but that way we would have to insert each dwarf by a
statement on its own.
Here paramater arrays come to the rescue:

```Red
insert snowwhite [
    "INSERT INTO Dwarves (Num, Name) VALUES (?, ?)"
    [1 "Dopey"] [2 "Doc"] [3 "Bashful"] [4 "Sneezy"] [5 "Happy"] [6 "Grumpy"] [7 "Sleepy"]
]
```

Array parameters are passed as blocks of parameter sets.

NOTE 1: It is ***not*** possible to use batched statements together with
parameter arrays.

NOTE 2: If you only have one parameter set, then `insert ["..." 1 "Dopey"]` is
just a shorter form for `insert ["..." [1 "Dopey"]]`.


# Column Names

## Column Names as Words

As you have seen, for SELECT statements, `insert` returns
a block of column names as [kebap-cased](https://en.wiktionary.org/wiki/kebab_case)
Red words instead of their original names in the database.

That way it's easy to keep your Red code in sync with your SQL statements:

```Red
columns: insert statement ["SELECT ID, Category, Title FROM Film"]
== [id category title]
foreach :columns copy statement [print [id title]]
1 A Kung Fu Hangman
2 Holy Cooking
3 The Low Calorie Guide to the Internet
...
```

If you later change your SQL statement to something like

```Red
insert statement [{SELECT ID, "Playing Now", "Tickets Sold", Title FROM Film}]
== [id playing-now tickets-sold title]
```

your retrieval code will still work without any modifications.

## Column Names as Strings

To retrieve column names as strings, on scheme, connection or statement level set

```Red
system/schemes/odbc/state/names?: true
```

```Red
change connection [names?: true]
```


```Red
change statement [names?: true]
```

On statement, connection and scheme level, `names?` may be set to `true` or `false`. On statement and connection level it
can also be set to `none` to delegate the decision from the statement to the connection and from the connection to the scheme.

With `names?: true`, columns will be returned as
```Red
columns: insert statement ["SELECT ID, Category, Title FROM Film"]
== ["ID" "Category" "Title"]
```

# Preparing Statements
Often, you'll find yourself executing the same SQL statements again and again.
The ODBC scheme therefor will automatically prepare a statement for later reuse
(i.e. execution), which saves the ODBC driver and your database the effort to
parse the SQL and to determine an access plan every single time. Instead, a
previously prepared statement is reused and no statement string needs to be
transfered to the database.

To prepare a statements, just `insert` a SQL string, likely along with maybe
some parameter markers `?` and parameters. On successive calls to `insert` with
the exact same SQL string on the same statement, the statement will only be
executed with maybe other parametes, but the SQL string doesn't need to be
prepared again.

Successive calls to `insert` may of course supply different parameter values:

```Red
sql: "SELECT * FROM Table WHERE Value = ?"

statement: open database: open odbc://mydatabase

insert statement [sql 1]
copy   statement
insert statement [sql 2]
copy   statement
insert statement [sql 3]
copy   statement

close  database
```

The more complex your statement is, the more noticable the speed gain
achievable with prepared statements should get.

Whether a SQL string supplied needs to be prepared before execution or whether
it can be excecuted right away, is determined by the `same?`-ness of the SQL
strings supplied:

```Red
products:  "SELECT * FROM Product  WHERE ProductID  = ?"
customers: "SELECT * FROM Customer WHERE CustomerID = ?"

statement: open database: open odbc://database

insert statement [products  1]      ;-- preparation and execution
insert statement [products  2]      ;-- execution only
insert statement [customers 3]      ;-- preparation and execution
insert statement [customers 4]      ;-- execution only
insert statement [products  5]      ;-- again, preparation and execution
```

To prepare multiple statements, just `open` one statement per SQL string
instead of inserting different SQL strings into the same statement.

# Datatype Conversions
If the built in automatic type conversion for data retrieval doesn't fit your
needs, you may cast values to different types in your SQL statement:

```Red
insert statement "SELECT Weight FROM Person LIMIT 1"
type? first first copy statement
== float!
insert statement "SELECT CAST(Weight AS INTEGER) FROM Person LIMIT 1"
type? first first copy statement
== integer!
```

Statement parameters inserted into the result columns will always be returned
as strings unless told otherwise:

```Red
insert statement ["SELECT ? FROM Person LIMIT 1" 1]
type? first first copy statement
== string!
insert statement ["SELECT CAST(? AS INTEGER) FROM Person LIMIT 1" 1]
type? first first copy statement
== integer!
```

If there is no applicable Red datatype to contain a SQL value, the value will
be returned as a string.


# Transactions
Transactions in ODBC are completed at the connection level. By default, ODBC
transactions are in autocommit mode. You may change the commit mode by setting
`connection/state/commit?` to either `yes` or `no` (manual commit mode).

In manual commit mode, a transaction is committed by

```
insert connection 'commit
```

and is rolled back by

```
insert connection 'rollback
```


# Native SQL
Sometimes it can be useful to see how the ODBC driver translates an SQL
string to native SQL:

```Red
insert connection [native "SELECT * FROM test.csv WHERE year = 2022"]
== {SELECT *^M^/FROM [test].csv^M^/WHERE year = 2022;^M^/}
```

Note that this operates on a connection, not on a statement.

# State Information

Once opened, a whole whealth of information about connection and statement ports is available with `query`:

```Red
query connection
== #(
    "accessible-procedures" false
    "accessible-tables" false
    "active-environments" ...
              :
```

```Red
query statement
== #(
    "app-param-desc" handle!
    "app-row-desc" handle!
    "async-enable" ...
           :
```

Similiar information can be retrieved for the whole ODBC environment from the scheme with

```Red
system/schemes/odbc/state/query
== #(
    "cp-match" strict
    "odbc-version" 3.0
    "output-nts" true
)
```


# Catalog Functions

Besides executing SQL statements, `insert` too supports all ODBC catalog
functions.

If a catalog function doesn't require mandatory arguments,
supplying only a word! instead of a block! argument will do:

```Red
columns: insert statement 'tables
tables:  copy   statement
```

will, for example, return a list of all tables in a data source.

To narrow down results supply a block (which in case of
catalog functions *won't* be `reduce`, so you'll need to `reduce`,
`compose` or otherwise build the block by yourself):

```Red
columns: insert statement [tables "customs" "tariffs"]
tables:  copy   statement
```

will only return tables within database "customs" and schema "tariffs".

###### Catalog dialect

The signature of the catalog functions is as follows:

| word          | block |
|---------------|---|
|               | `[column privileges <cat> <schema> <tbl> <col>]` |
| `'columns`    | `[columns <cat> <schema> <tbl> <col>]` |
|               | `[foreign keys <cat/pk> <schema/pk> <tbl/pk> <cat/fk> <schema/fk> <tbl/fk>]` |
|               | `[special columns [unique \| update \| none!] <cat> <schema> <tbl> [row \| transaction \| session \| none!] [logic! \| none!]]` |
|               | `[primary keys <cat> <schema> <tbl>]` |
|               | `[procedure columns <cat> <schema> <tbl> <col>]` |
| `'procedures` | `[procedures catalog <schema> <proc>]` |
| `'statistics` | `[statistics <cat> <schema> <tbl> [all \| unique \| none!]]` |
|               | `[table privileges <cat> <schema> <tbl>]` |
| `'tables`     | `[tables <cat> <schema> <tbl> <type>]` |
| `'types`      | `[types]` |

with

* `cat` being a catalog name string or `none`,
* `schema` being a schema name string or `none`,
* `tbl` being a table name string or `none`,
* `col` being a column name string or `none`,
* `proc` being a procedure name string or `none` and
* `type` being a table type name string or `none`.

Note that `foreign keys` takes two sets of names for primary (1st) and foreign
(2nd) keys.

Only some catalog expect arguments are not of type `string!` but of type
`word!` or `logic!`:

* `statistics` has a forth argument for the index type (default is `all`)
* `special columns`' first argument identifies the type of columns to return,
either the optimal (set of) column(s) to `unique`ly identify a row or the (set
of) column(s) automatically `update`d when any value in the row is updated.
* `special columns`' fifth argument, the row id scope, has a default value
of `row`, but can also be `transaction` or `session`
* `special columns`' sixth argument, the nullability, has a default value
of `false`, with `true` special columns are returned even if they can have
null values.

Literal words `none` and `on`, `off`, `true`, `false`, `yes`, `no` will be recognized and converted
to their usual value of type `none!` or `logic!`.

###### Pattern Matching vs. Strict Mode, Case-(In)Sensitivity

String arguments to the catalog functions can be either ordinary arguments
(OA), case-sensitive pattern value arguments (PV) allowing for underscore `_`
and percent sign `%` wildcards, or value list arguments (VL).

With `insert`, the default mode for pattern value arguments to catalog
functions is pattern matching.

To treat strings as case-insensitive identifier arguments (ID) and to avoid
pattern matching start the dialect block with `strict` as in e.g.
`insert statement [strict tables none none "cust%"]`.
That way, searching for tables named "cust%" will find neither tables named
"customer" nor "customs", but only tables literally named "cust%" with the
percent sign being part of their name.

For more details see the ODBC API documention.