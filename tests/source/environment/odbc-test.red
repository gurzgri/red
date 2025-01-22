Red [
	Title:   "Red ODBC tests"
	Author:  "Christian Ensel"
	File:    %tests/odbc-test.red
	Tabs:    4
	Rights:  "Copyright 2022 Christian Ensel"
	License: 'Unlicensed
]

#include  %../../../quick-test/quick-test.red
#include  %odbc-test-integration.red                    ;-- NOTE: deliberatly .gitignore'd

~~~start-file~~~ "odbc"

===start-group=== "prerequisites tests"

	;-- If the following testing requirements aren't met, most consecutive
	;   tests will fail, too. However, these env-vars aren't required for
	;   anything other than running these tests.

	--test-- {can get-env "TESTDSN"}  --assert not none? get-env "TESTDSN"
	--test-- {can get-env "TESTDRVR"} --assert not none? get-env "TESTDRVR"
	--test-- {can get-env "TESTSRVR"} --assert not none? get-env "TESTSRVR"
	--test-- {can get-env "TESTPORT"} --assert not none? get-env "TESTPORT"
	--test-- {can get-env "TESTDB"}   --assert not none? get-env "TESTDB"
	--test-- {can get-env "TESTUID"}  --assert not none? get-env "TESTUID"
	--test-- {can get-env "TESTPWD"}  --assert not none? get-env "TESTPWD"
	--test-- {can get-env "TESTCSV"}  --assert not none? get-env "TESTCSV"

===end-group===

===start-group=== "environment tests"

	--test-- "can lists drivers" --assert block? system/schemes/odbc/state/drivers
	--test-- "can lists sources" --assert block? system/schemes/odbc/state/sources

===end-group===

===start-group=== "connection tests"

	--test-- "can connect by ODBC datasource name"
		--assert not error? try [
			url: rejoin [odbc:// get-env "TESTDSN"]     ;-- required to be set for
			close open url                              ;   the test to succeed
		]

	--test-- "can connect by ODBC connection string"
		--assert not error? try [
			set/any 'outcome try [
				conn: open make port! [scheme: 'odbc target: rejoin [
					"Driver="       get-env "TESTDRVR"  ;-- required to be set for
					";Server="      get-env "TESTSRVR"  ;   the test to succeed
					";Port="        get-env "TESTPORT"
					";Database="    get-env "TESTDB"
					";Uid="         get-env "TESTUID"
					";Pwd="         get-env "TESTPWD"
				]
			]]
			all [conn  close conn]
			outcome
		]

	--test-- "can set state/commit?"
		--assert not error? try [
			close change open rejoin [odbc:// get-env "TESTDSN"] [commit?: no]
		]

	--test-- "can manually commit a transaction"
		--assert not error? try [
			change conn: open rejoin [odbc:// get-env "TESTDSN"] [commit?: no]
			insert open conn "UPDATE public.sourcings SET name = 'Test'"
			insert conn 'commit
			close conn
		]

	--test-- "can translate to native sql on connection"
		--assert equal? "SELECT cint(4711);^M^/" try [
			also insert conn: open rejoin [odbc:// get-env "TESTCSV"] "SELECT {fn CONVERT(4711, SQL_SMALLINT)}" close conn
		]

	--test-- "can translate to native sql with block and params"
		--assert equal? {PARAMETERS Pa_RaM000 Value;^M^/SELECT cint(Pa_RaM000);^M^/} try [
			also insert conn: open rejoin [odbc:// get-env "TESTCSV"] ["SELECT {fn CONVERT(?, SQL_SMALLINT)}" 4711] close conn
		]

===end-group===

===start-group=== "parameter tests"

	--test-- "can handle params not given as prmsets"
		--assert zero? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT caption FROM depot2019.schools WHERE school_id = ?" "4711"]
			also length? copy test close conn
		]

	--test-- "can detect prmsets not being blocks"
		--assert equal? 'expect-val try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			set/any 'error try [
				insert test ["SELECT caption FROM depot2019.schools WHERE id = ?" [] 1]
			]
			close conn
			error/id
		]

	--test-- "can detect prmsets of different lengths"
		--assert equal? 'invalid-arg try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			set/any 'error try [
				insert test ["SELECT caption FROM depot2019.schools WHERE id = ?" [1] [1 2]]
			]
			close conn
			error/id
		]

	--test-- "can detect prmsets with unmatched types"
		--assert equal? 'not-same-type try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			set/any 'error try [
				insert test ["SELECT caption FROM depot2019.schools WHERE id = ?" [1 "test"] [1 2]]
			]
			close conn
			error/id
		]

	--test-- "can detect prmsets with unmatched types, but allows late NONE"
		--assert not error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT caption FROM depot2019.schools WHERE school_id = ? AND caption = ?" [1 "Test"] [1 #(none)]]
			close conn
		]

	--test-- "can detect prmsets with unmatched types, but allows early NONE"
		--assert not error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT caption FROM depot2019.schools WHERE school_id = ? AND caption = ?" [1 #(none)] [1 "Test"]]
			close conn
		]

	--test-- "can handle prmsets with all NONE column"
		--assert not error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT caption FROM depot2019.schools WHERE school_id = ?" [#(none)] [#(none)]]
			close conn
		]

	--test-- "can handle empty prmsets error gracefully"
		--assert equal? 'bad-bad try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			set/any 'error try [
				insert test ["SELECT caption FROM depot2019.schools WHERE school_id = ?" [] []]
			]
			close conn
			error/id
		]

	--test-- "can use string params"
		--assert equal? 3 try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT caption FROM depot2019.schools WHERE school_id = ?" ["13891"] ["59013"] ["40324"]]
			length? also collect [until [keep copy test none? update test]] close conn
		]

	--test-- "can round trip strings"
		--assert equal? {[["13891"] ["59013"] ["40324"]]} try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT ?::char(5)" ["13891"] ["59013"] ["40324"]]
			also mold/all new-line/all collect [until [keep copy test none? update test]] off close conn
		]

	--test-- "can exchange the various string types"
		--assert equal? rejoin [
			{[}
			{["string" "file" "http://url" "tag" "e@mail" "ref"] }
			{["ref" "string" "file" "http://url" "tag" "e@mail"] }
			{["e@mail" "ref" "string" "file" "http://url" "tag"] }
			{["tag" "e@mail" "ref" "string" "file" "http://url"] }
			{["http://url" "tag" "e@mail" "ref" "string" "file"] }
			{["file" "http://url" "tag" "e@mail" "ref" "string"]}
			{]}
		] try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test [
				"select ?, ?, ?, ?, ?, ?"
				["string" %file http://url <tag> e@mail @ref]
				[@ref "string" %file http://url <tag> e@mail]
				[e@mail @ref "string" %file http://url <tag>]
				[<tag> e@mail @ref "string" %file http://url]
				[http://url <tag> e@mail @ref "string" %file]
				[%file http://url <tag> e@mail @ref "string"]
			]
			also mold/all new-line/all collect [until [keep copy test none? update test]] off close conn
		]

	--test-- "can use time params"
		--assert equal? {[["0"] ["1"] ["0"]]} try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT '14:15:16'::time = ?" [11:12:13] [14:15:16] [17:18:19]]
			also mold/all new-line/all collect [until [keep copy test none? update test]] off close conn
		]

	--test-- "can round trip times"
		--assert equal? {[[11:12:13] [14:15:16] [17:18:19]]} try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT ?::time" [11:12:13] [14:15:16] [17:18:19]]
			also mold/all new-line/all collect [until [keep copy test none? update test]] off close conn
		]

	--test-- "can round trip integers"
		--assert equal? {[[-2147483648] [0] [2147483647]]} try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT ?::integer" [-2147483648] [0] [2147483647]]
			also mold/all new-line/all collect [until [keep copy test none? update test]] off close conn
		]

	--test-- "can round trip floats"
		--assert equal? {[[-1.7976931348623e308] [0.0] [1.7976931348623e308]]} try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert test ["SELECT ?::double precision" [-1.7976931348623e308] [0.0] [1.7976931348623e308]]
			also mold/all new-line/all collect [until [keep copy test none? update test]] off close conn
		]

===end-group===

===start-group=== "datatypes tests"

	--test-- "can fetch integers"
		--assert equal? "[[-2147483648 -1 0 1 2147483647]]" try [
			insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT -2147483648, -1, 0, 1, 2147483647}
			also mold/all new-line/all copy test off close conn
		]

	--test-- "can fetch strings"
		--assert equal? {[["" "test"]]} try [
			insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT '', 'test' }
			also mold/all new-line/all copy test off close conn
		]

	--test-- "can fetch times"
		--assert equal? {[[8:00:00 11:12:13 24:00:00]]} try [
			insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT '08:00'::time, '11:12:13'::time, '24:00:00'::time }
			also mold/all new-line/all copy test off close conn
		]

	--test-- "can fetch times with fractions of seconds"
		--assert equal? 3.123456789 try [
			insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT '01:02:03.123456789'::time }
			time: first first copy test
			close conn
			time/seconds
		]

	--test-- "can fetch dates anno Domini (AD) up to year 9999"
		--assert equal? {[[31-Dec-4713 31-Dec-9999]]} try [
			insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT '4713-12-31'::date, '9999-12-31'::date }
			also mold/all new-line/all copy test off close conn
		]

	--test-- "can fetch date/time anno Domini (AD) up to year 9999"
		--assert equal? {[[31-Dec-4713/11:12:13 31-Dec-9999/14:15:16]]} try [
			insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT '4713-12-31 11:12:13'::timestamp, '9999-12-31 14:15:16'::timestamp }
			also mold/all new-line/all copy test off close conn
		]

===end-group===

===start-group=== "table tests"

	--test-- "can read all depot2019.articles"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.articles }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.articles_multi"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.articles_multi }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.authorities"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.authorities }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.depots"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.depots }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.messages"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.messages }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.orders"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.orders }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.packings"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.packings }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.placings"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.placings }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.publishers"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.publishers }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.pupils"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.pupils }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.receipts"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.receipts }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.receivings"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.receivings }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.reorders"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.reorders }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.roles"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.roles }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.schools"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.schools }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.sources"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.sources }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.sourcings"         ;-- NOTE: crashes for postgres' bytea
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT creation_date, filename, /* document, */ placing_ids, sourcing_id, supplier_ids, user_id FROM depot2019.sourcings }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.stockings"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.stockings }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.stocks"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.stocks }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.suppliers"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.suppliers }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.updates"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.updates }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.users"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.users }
		--assert not error? try [copy test close conn]

	--test-- "can read all depot2019.warnings"
		insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] { SELECT * FROM depot2019.warnings }
		--assert not error? try [copy test close conn]

===end-group===

===start-group=== "paging tests"

	--test-- "can set state/window"
		--assert equal? 2 try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			test/state/window: 2
			insert test { SELECT 1 AS a UNION SELECT 2 AS a UNION SELECT 3 AS a ORDER BY a }
			length? also next test close conn
		]

	--test-- "can use INDEX? before paging"
		--assert none? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			test/state/window: 2
			insert test { SELECT 1 AS a UNION SELECT 2 AS a UNION SELECT 3 AS a ORDER BY a }
			also try [index? test] close conn
		]

	--test-- "can use INDEX? after paging"
		--assert not error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			test/state/window: 2
			insert test { SELECT 1 AS a UNION SELECT 2 AS a UNION SELECT 3 AS a ORDER BY a }
			index? next test
			close conn
		]

	--test-- "can not page back with forward-only cursor"
		--assert error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			insert/part test { SELECT 1 AS a UNION SELECT 2 AS a UNION SELECT 3 AS a ORDER BY a } 2
			next test
			also try [back test] close conn
		]

	--test-- "can set static cursor"
		--assert not error? try [
			change test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [window: 2 access: 'static]
			insert test { SELECT 1 AS a UNION SELECT 2 AS a UNION SELECT 3 AS a ORDER BY a }
			back next test
			close conn
		]

	--test-- "can open and rename a cursor"
		--assert not error? try [
			conn: open rejoin [odbc:// get-env "TESTDSN"]
			change stmt: open conn [window: 1 access: 'static]
			change cursor: open stmt "CURROW"
			close conn
		]

	--test-- "may overlap when back paging"
		--assert equal? 2 try [
			change test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [window: 2 access: 'static]
			insert test { SELECT 1 AS a UNION SELECT 2 AS a UNION SELECT 3 AS a UNION SELECT 4 AS a UNION SELECT 5 AS a ORDER BY a }
			loop 3 [rows: next test]                    ;-- rows = []
			loop 2 [rows: back test]
			close conn
			length? rows
		]

===end-group===

===start-group=== "rowset positioning tests"

	--test-- "INDEX?  on unexecuted statement returns NONE"  --assert none? try [also index?  open conn: open rejoin [odbc:// get-env "TESTDSN"] close conn]
	--test-- "HEAD?   on unexecuted statement returns NONE"  --assert none? try [also head?   open conn: open rejoin [odbc:// get-env "TESTDSN"] close conn]
	--test-- "TAIL?   on unexecuted statement returns NONE"  --assert none? try [also tail?   open conn: open rejoin [odbc:// get-env "TESTDSN"] close conn]
	--test-- "LENGTH? on unexecuted statement returns zero"  --assert zero? try [also length? open conn: open rejoin [odbc:// get-env "TESTDSN"] close conn]

	--test-- "INDEX? after statement execution returns NONE" --assert none? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] "SELECT * FROM public.schools" also index?  test close conn]
	--test-- "HEAD?  after statement execution returns NONE" --assert none? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] "SELECT * FROM public.schools" also head?   test close conn]
	--test-- "TAIL?  after statement execution returns NONE" --assert none? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] "SELECT * FROM public.schools" also tail?   test close conn]

	bite: func [series] [remove back tail series series]
	sql:  form collect [
		keep bite collect [repeat i 64 [keep reduce ['SELECT i 'UNION]]]
		keep [ORDER BY 1]
	]
	short: func [block] [new-line/all block off]

	conn: open rejoin [odbc:// get-env "TESTDSN"]

	--test-- "can navigate to rowset with NEXT"
		--assert equal? {[[1 2 3 4 5 6 7 8 9 10 11 12 13] [14 15 16 17 18 19 20 21 22 23 24 25 26] [27 28 29 30 31 32 33 34 35 36 37 38 39] [40 41 42 43 44 45 46 47 48 49 50 51 52] [53 54 55 56 57 58 59 60 61 62 63 64] []]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [until [empty? keep/only short next test]] close test
		]

	--test-- "can navigate to rowset with BACK"
		--assert equal? {[[52 53 54 55 56 57 58 59 60 61 62 63 64] [39 40 41 42 43 44 45 46 47 48 49 50 51] [26 27 28 29 30 31 32 33 34 35 36 37 38] [13 14 15 16 17 18 19 20 21 22 23 24 25] [1 2 3 4 5 6 7 8 9 10 11 12 13] []]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short tail test until [empty? keep/only short back test]] close test
		]

	--test-- "can navigate to rowset with AT"
		--assert equal? {[[64] [51 52 53 54 55 56 57 58 59 60 61 62 63] [1 2 3 4 5 6 7 8 9 10 11 12 13]]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [foreach index [91 51 1] [keep/only short at test index]] close test
		]

	--test-- "can navigate to rowset with SKIP"
		--assert equal? {[[20 21 22 23 24 25 26 27 28 29 30 31 32] [40 41 42 43 44 45 46 47 48 49 50 51 52] [60 61 62 63 64] []]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [until [empty? keep/only short skip test 20]] close test
		]

	--test-- "can navigate to rowset with HEAD and TAIL"
		--assert equal? {[[52 53 54 55 56 57 58 59 60 61 62 63 64] [1 2 3 4 5 6 7 8 9 10 11 12 13]]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short tail test keep/only short head test] close test
		]

	--test-- "can check if current rowset is the HEAD? rowset"
		--assert equal? {[[1 2 3 4 5 6 7 8 9 10 11 12 13] true [14 15 16 17 18 19 20 21 22 23 24 25 26] none]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short next test keep head? test keep/only short next test keep head? test] close test
		]

	--test-- "can check if current rowset is the TAIL? rowset"
		--assert equal? {[[52 53 54 55 56 57 58 59 60 61 62 63 64] true [39 40 41 42 43 44 45 46 47 48 49 50 51] none]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short tail test keep tail? test keep/only short back test keep tail? test] close test
		]

	--test-- "can navigate before HEAD rowset, returning empty rowset"
		--assert equal? "[[1 2 3 4 5 6 7 8 9 10 11 12 13] []]" try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short head test keep/only short back test] close test
		]

	--test-- "can navigate beyond TAIL rowset, returning empty rowset"
		--assert equal? "[[52 53 54 55 56 57 58 59 60 61 62 63 64] []]" try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short tail test keep/only short next test] close test
		]

	--test-- "can test for HEAD? rowset before HEAD rowset"
		--assert equal? "[[1 2 3 4 5 6 7 8 9 10 11 12 13] [] none]" try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short head test keep/only short back test keep head? test] close test
		]

	--test-- "can test for TAIL? rowset beyond TAIL rowset"
		--assert equal? {[[52 53 54 55 56 57 58 59 60 61 62 63 64] [] none]} try [
			insert change test: open conn [flat?: yes access: 'static window: 13] sql
			also mold collect [keep/only short tail test keep/only short next test keep tail? test] close test
		]

	close conn

===end-group===

===start-group=== "cursor positioning tests"

	sql:  form collect [
		keep bite collect [repeat i 64 [keep 'SELECT keep rejoin ["'\x" skip form to-hex i 6 "'::BYTEA AS HEX"] keep 'UNION]]
		keep [ORDER BY 1]
	]

	conn: open rejoin [odbc:// get-env "TESTDSN"]

	--test-- "can navigate cursor to HEAD of rowset (first row)"
		--assert equal? "[1 #{20}]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 head cursor keep index? cursor keep pick cursor 'hex] close test
		]

	--test-- "can navigate cursor to TAIL of rowset (last row)"
		--assert equal? "[8 #{27}]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 tail cursor keep index? cursor keep pick cursor 'hex] close test
		]

	--test-- "can navigate cursor to row in rowset using AT"
	  	--assert equal? "[4 #{23}]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 at cursor 4 keep index? cursor keep pick cursor 'hex] close test
		]

	--test-- "can (try to) navigate out of rowset with AT, returning none"
		--assert equal? "[none none]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 keep at cursor 16 keep at cursor -16] close test
		]

	--test-- "can navigate cursor to row in rowset using SKIP"
		--assert equal? "[6 #{25}]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 at cursor 4 skip cursor 2 keep index? cursor keep pick cursor 'hex] close test
		]

	--test-- "can (try to) navigate out of rowset with SKIP, returning none"
		--assert equal? "[none none]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 at cursor 4 keep skip cursor 16 keep at cursor -16] close test
		]

	--test-- "can navigate forwards in rowset using NEXT"
		--assert equal? "[1 #{20} 2 #{21} 3 #{22} 4 #{23} 5 #{24} 6 #{25} 7 #{26} 8 #{27}]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 head cursor until [keep index? cursor keep pick cursor 'hex none? next cursor]] close test
		]

	--test-- "can navigate backwards in rowset using BACK"
		--assert equal? "[8 #{27} 7 #{26} 6 #{25} 5 #{24} 4 #{23} 3 #{22} 2 #{21} 1 #{20}]" try [
			cursor: open test: open conn
			insert change test [flat?: yes access: 'static window: 8] sql
			also mold short collect [at test 32 tail cursor until [keep index? cursor keep pick cursor 'hex none? back cursor]] close test
		]

	close conn

===end-group===

===start-group=== "catalog tests"

	--test-- "can catalog column privileges"    --assert not error? try [also try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [column privileges "lmf" "depot2019" "schools" "school_id"]] close conn]
	--test-- "can catalog columns"              --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] 'columns close conn]
	--test-- "can catalog foreign keys"         --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [foreign keys "lmf" "depot2019" "schools"] close conn]
	--test-- "can catalog primary keys"         --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [primary keys "lmf" "depot2019" "schools"] close conn]
	--test-- "can catalog procedure columns"    --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [procedure columns] close conn]
	--test-- "can catalog procedures"           --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] 'procedures close conn]
	--test-- "can catalog special columns"      --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [special columns unique "lmf" "depot2019" "orders"] close conn]
	--test-- "can catalog statistics"           --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [statistics "lmf" "depot2019" "schools"] close conn]
	--test-- "can catalog table privileges"     --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] [table privileges] close conn]
	--test-- "can catalog tables"               --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] 'tables close conn]
	--test-- "can catalog types"                --assert not error? try [insert test: open conn: open rejoin [odbc:// get-env "TESTDSN"] 'types close conn]

===end-group===

===start-group=== "options tests"

	--test-- "can return flat"
		system/schemes/odbc/state/flat?: yes
		test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
		insert test "SELECT 1 UNION SELECT 2 UNION SELECT 3"
		rows: copy test
		close conn
		system/schemes/odbc/state/flat?: no
		--assert equal? {[^/    1 ^/    2 ^/    3^/]} mold/all rows

===end-group===

===start-group=== "function sequence tests"

	--test-- "can execute same statement twice"
		--assert not error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			loop 2 [insert test "SELECT 'Test'"]
			close conn
		]

	--test-- "can exceute same parameterized statement twice"
		--assert not error? try [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			loop 2 [insert test ["SELECT 'Test' = ?" "Test"]]
			close conn
		]

	--test-- "can do batched statements"
		--assert equal? {[[col-1] [^/    [1]^/] [col-1 col-2] [^/    [1 2]^/]]} attempt [mold collect [
			test: open conn: open rejoin [odbc:// get-env "TESTDSN"]
			keep/only insert test "SELECT 1 AS Col1; SELECT 1 AS Col1, 2 AS Col2"
			keep/only copy test
			keep/only update test
			keep/only copy test
			close conn
		]]

===end-group===

===start-group=== "text driver csv tests"

	--test-- "can prepare tables"                       ;-- not a test at all, merely preparation for further tests
		columns: rejoin ["BitCol;ByteCol;ShortCol;LongCol;SingleCol;DoubleCol;DateCol;DateTimeCol;TextCol;MemoCol" lf]
		make-dir path: append what-dir %odbc/
		write path/"schema.ini" form collect [foreach table ["ANSI" "OEM" "Unicode"] [
			either table = "Unicode" [
				write/binary rejoin [path table %.csv] #{
					fffe42006900740043006f006c003b00420079007400650043006f006c003b00
					530068006f007200740043006f006c003b004c006f006e00670043006f006c00
					3b00530069006e0067006c00650043006f006c003b0044006f00750062006c00
					650043006f006c003b00440061007400650043006f006c003b00440061007400
					6500540069006d00650043006f006c003b00540065007800740043006f006c00
					3b004d0065006d006f0043006f006c000d000a00
				}
			][
				write rejoin [path table %.csv] columns
			]
			keep rejoin [
				"[" table %.csv "]"                 lf
				'ColNameHeader=          'True      lf
				'Format=          "Delimited(;)"    lf
				'MaxScanRows=                0      lf
				'CharacterSet= uppercase table      lf
				'Col1= "BitCol      Bit       "     lf
				'Col2= "ByteCol     Byte      "     lf
				'Col3= "ShortCol    Short     "     lf
				'Col4= "LongCol     Long      "     lf
				'Col5= "SingleCol   Single    "     lf
				'Col6= "DoubleCol   Double    "     lf
				'Col7= "DateCol     Date      "     lf
				'Col8= "DateTimeCol DateTime  "     lf
				'Col9= "TextCol     Text      "     lf
				'Col10="MemoCol     Memo      "     lf
				'DecimalSymbol=             "."     lf
				'NumberDigits=              10      lf
				'NumberLeadingZeros=         1      lf
			]]
		]
		--assert true

	--test-- "can insert into csv with text driver"
		connection-string: rejoin ["Driver={Microsoft Text Driver (*.txt; *.csv)};Dbq=[" to-local-file append what-dir %odbc/ "];Extensions=csv;"]
		csv: open jet: open make port! [scheme: 'odbc target: connection-string]
		foreach table ["ANSI" "OEM" "Unicode"] [
			insert csv rejoin [{
				INSERT INTO } table {.csv ( BitCol, ByteCol, ShortCol,     LongCol,    SingleCol,            DoubleCol,          DateCol,                DateTimeCol,          TextCol,         MemoCol)
				VALUES                    (      0,       0,   -32768, -2147483648, -3.402823E38, -1.7976931348623e308, {d '0100-01-01'}, {ts '0100-01-01 11:22:33'},  'Line1^M^/Line2', '∃Ⅻↀↁↇↈ∰');
			}]
			insert csv rejoin [{
				INSERT INTO } table {.csv ( BitCol, ByteCol, ShortCol,     LongCol,    SingleCol,            DoubleCol,          DateCol,                DateTimeCol,           TextCol,        MemoCol)
				VALUES                    (      1,     255,    32767,  2147483647,  3.402823E38,  1.7976931348623e308, {d '9999-12-31'}, {ts '9999-12-31 23:59:59'},  'Line1^M^/Line2', '∃Ⅻↀↁↇↈ∰');
			}]
			insert csv rejoin [{SELECT * FROM } table {.csv}]
			copy csv

			;-- FIXME:  No matter what I'm trying, I can't get parameter handling working with the text driver, only getting
			;           HYC00 106 {[Microsoft][ODBC Text Driver] Optional Feature not implemented

		;   insert csv reduce [
		;       rejoin [{
		;           INSERT INTO } table {.csv ( BitCol, ByteCol, ShortCol, LongCol, SingleCol, DoubleCol, DateCol, DateTimeCol, TextCol, MemoCol)
		;           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
		;       }]
		;       #[false] 255 -32768 -2147483648 -3.402823e38 -1.7976931348623e308 1-Jan-100 1-Jan-100/11:22:33 "Line1^M^/Line2" "∃Ⅻↀↁↇↈ∰"
		;   ]
		;   insert csv reduce [
		;       rejoin [{
		;           INSERT INTO } table {.csv ( BitCol, ByteCol, ShortCol, LongCol, SingleCol, DoubleCol, DateCol, DateTimeCol, TextCol, MemoCol)
		;           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
		;       }]
		;       #[true] 255 32767 2147483647 3.402823e38 1.7976931348623e308 31-Dec-9999 31-Dec-9999/23:59:59 "Line1^M^/Line2" "∃Ⅻↀↁↇↈ∰"
		;   ]
		;   insert csv rejoin [{SELECT * FROM } table {.csv}]
		;   copy csv
		]
		close jet
		--assert true

===end-group===

~~~end-file~~~