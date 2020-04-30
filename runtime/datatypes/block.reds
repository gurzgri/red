Red/System [
	Title:   "Block! datatype runtime functions"
	Author:  "Nenad Rakocevic"
	File: 	 %block.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

block: context [
	verbose: 0
	
	depth: 0											;-- used to trace nesting level for FORM/MOLD

	compare-arg-a: as red-value! 0
	compare-arg-b: as red-value! 0

	rs-length?: func [
		blk 	[red-block!]
		return: [integer!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(blk)
		(as-integer (s/tail - s/offset)) >> 4 - blk/head ;-- warning: can be negative for past-end indexes!
	]
	
	rs-next: func [
		blk 	[red-block!]
		return: [logic!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(blk)
		if (s/offset + blk/head + 1) <= s/tail [
			blk/head: blk/head + 1
		]
		s/offset + blk/head = s/tail
	]
	
	rs-head: func [
		blk 	[red-block!]
		return: [red-value!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(blk)
		s/offset + blk/head
	]
	
	rs-tail: func [
		blk 	[red-block!]
		return: [red-value!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(blk)
		s/tail
	]
	
	rs-tail?: func [
		blk 	[red-block!]
		return: [logic!]
		/local
			s [series!]
	][
		s: GET_BUFFER(blk)
		s/offset + blk/head = s/tail
	]

	rs-abs-at: func [
		blk 	[red-block!]
		pos		[integer!]
		return: [red-value!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(blk)
		assert s/offset + pos < s/tail
		s/offset + pos
	]
	
	rs-clear: func [
		blk 	[red-block!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(blk)
		s/tail: s/offset + blk/head
	]
	
	rs-append: func [
		blk		[red-block!]
		value	[red-value!]
		return: [red-value!]
	][
		copy-cell value ALLOC_TAIL(blk)
	]
	
	rs-append-block: func [
		blk		[red-block!]
		blk2	[red-block!]
		return: [red-block!]
		/local
			value [red-value!]
			tail  [red-value!]
			s	  [series!]
	][
		s: GET_BUFFER(blk2)
		value: s/offset + blk2/head
		tail:  s/tail

		while [value < tail][
			copy-cell value ALLOC_TAIL(blk)
			value: value + 1
		]
		blk
	]
	
	rs-select: func [
		blk		[red-block!]
		value	[red-value!]
		return: [red-value!]
		/local
			slot [red-value!]
			tail [red-value!]
			s	 [series!]
			compare
	][
		s: GET_BUFFER(blk)
		slot: s/offset + blk/head
		tail: s/tail
		compare: DISPATCH_COMPARE(value)

		while [slot < tail][
			if zero? compare value slot COMP_FIND [
				slot: slot + 1
				either slot < tail [return slot][return as red-value! none-value]
			]
			slot: slot + 1
		]
		as red-value! none-value
	]

	clone: func [
		blk 	[red-block!]
		deep?	[logic!]
		any?	[logic!]
		return: [red-block!]
		/local
			new	   [red-block!]
			node   [node!]
			target [series!]
			value  [red-value!]
			tail   [red-value!]
			result [red-block!]
			size   [integer!]
			type   [integer!]
			empty? [logic!]
	][
		assert any [
			TYPE_OF(blk) = TYPE_HASH
			TYPE_OF(blk) = TYPE_MAP
			TYPE_OF(blk) = TYPE_BLOCK
			TYPE_OF(blk) = TYPE_PAREN
			TYPE_OF(blk) = TYPE_PATH
			TYPE_OF(blk) = TYPE_SET_PATH
			TYPE_OF(blk) = TYPE_GET_PATH
			TYPE_OF(blk) = TYPE_LIT_PATH
		]
		
		value: block/rs-head blk
		tail:  block/rs-tail blk
		size:  (as-integer tail - value) >> 4
		
		empty?: zero? size
		if empty? [size: 1]
		
		new: as red-block! stack/push*					;-- slot allocated on stack!
		new/header: TYPE_UNSET
		new/head:   0
		new/node:	alloc-cells size
		new/extra:	0
		new/header:	TYPE_BLOCK

		unless empty? [
			target: GET_BUFFER(new)
			copy-memory
				as byte-ptr! target/offset
				as byte-ptr! value
				size << 4
			target/tail: target/offset + size
		]
		
		if all [deep? not empty?][
			value: target/offset
			tail: value + size
			while [value < tail][
				type: TYPE_OF(value)
				if any [
					type = TYPE_BLOCK
					all [
						any? 
						any [
							type = TYPE_PATH
							type = TYPE_SET_PATH
							type = TYPE_GET_PATH
							type = TYPE_LIT_PATH
							type = TYPE_PAREN
						]
					]
				][
					result: clone as red-block! value yes any?
					result/header: value/header
					copy-cell as red-value! result value
					stack/pop 1
				]
				value: value + 1
			]
		]
		new/header: TYPE_OF(blk)
		new
	]
	
	insert-value: func [
		blk		[red-block!]
		value	[red-value!]
		return: [red-block!]
		/local
			head   [red-value!]
			s	   [series!]
			size   [integer!]
	][
		s: GET_BUFFER(blk)
		size: as-integer s/tail + 1 - s/offset
		if size > s/size [s: expand-series s size * 2]
		head: s/offset + blk/head
		
		move-memory										;-- make space
			as byte-ptr! head + 1
			as byte-ptr! head
			as-integer s/tail - head
			
		s/tail: s/tail + 1	
		copy-cell value head
		blk/head: blk/head + 1
		blk
	]
	
	insert-block: func [
		blk		[red-block!]
		blk2	[red-block!]
		return: [red-block!]
		/local
			value [red-value!]
			tail  [red-value!]
			s	  [series!]
	][
		s: GET_BUFFER(blk2)
		value: s/offset + blk2/head
		tail:  s/tail
		
		while [value < tail][
			insert-value blk value
			value: value + 1
		]
		blk
	]
	
	insert-thru: does [
		unless stack/acc-mode? [
			insert-value
				as red-block! stack/arguments - 1
				stack/arguments
		]
	]
	
	append*: func [
		return: [red-block!]
		/local
			arg	[red-block!]
			val [red-value!]
			hs	[red-hash!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/append*"]]

		arg: as red-block! stack/arguments
		;assert TYPE_OF(arg) = TYPE_BLOCK				;@@ disabled until we have ANY_BLOCK check

		val: copy-cell
			as cell! arg + 1
			ALLOC_TAIL(arg)

		if TYPE_OF(arg) = TYPE_HASH [
			hs: as red-hash! arg
			_hashtable/put hs/table val
		]
		arg
	]
	
	append-thru: func [
		/local
			arg	[red-block!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/append-thru"]]

		unless stack/acc-mode? [
			arg: as red-block! stack/arguments - 1
			;assert TYPE_OF(arg) = TYPE_BLOCK			;@@ disabled until we have ANY_BLOCK check

			copy-cell
				as cell! arg + 1
				ALLOC_TAIL(arg)
		]
	]
	
	select-word: func [
		blk		[red-block!]
		word	[red-word!]
		case?	[logic!]
		return: [red-value!]
		/local
			value [red-value!]
			tail  [red-value!]
			w	  [red-word!]
			sym	  [integer!]
			sym2  [integer!]
	][
		value: rs-head blk
		tail:  rs-tail blk
		sym:   either case? [word/symbol][symbol/resolve word/symbol]
		
		while [value < tail][
			if any [									;@@ replace with ANY_WORD?
				TYPE_OF(value) = TYPE_WORD
				TYPE_OF(value) = TYPE_SET_WORD
				TYPE_OF(value) = TYPE_GET_WORD
				TYPE_OF(value) = TYPE_LIT_WORD
			][
				w: as red-word! value
				sym2: either case? [w/symbol][symbol/resolve w/symbol]
				if sym = sym2 [
					either value + 1 = tail [
						return none-value
					][
						return value + 1
					]
				]
			]
			value: value + 1
		]
		none-value
	]

	make-at: func [
		blk		[red-block!]
		size	[integer!]
		return: [red-block!]
	][
		if size < 0 [size: 1]
		
		set-type as cell! blk TYPE_UNSET				;-- preserve eventual newline flag
		blk/head: 	0
		blk/node: 	alloc-cells size
		blk/extra:  0
		set-type as cell! blk TYPE_BLOCK
		blk
	]
	
	preallocate: func [
		blk		[red-block!]
		size	[integer!]
		fixed?	[logic!]								;-- alloc fixed cells instead of unset ones.
		return: [red-block!]
	][
		if size < 0 [size: 1]
		blk/header: TYPE_UNSET
		blk/head: 	0
		either fixed? [
			blk/node: alloc-fixed-series size 16 0
		][
			blk/node: alloc-unset-cells size 16 0
		]
		blk/extra:  0
		blk/header: TYPE_BLOCK							;-- implicit reset of all header flags
		blk	
	]

	make-fixed: func [
		parent	[red-block!]
		size 	[integer!]								;-- number of cells to pre-allocate
		return:	[red-block!]
		/local
			blk [red-block!]
	][
		blk: either null? parent [
			_root
		][
			assert any [
				TYPE_OF(parent) = TYPE_BLOCK			;@@ replace with ANY_BLOCK
				TYPE_OF(parent) = TYPE_PAREN
				TYPE_OF(parent) = TYPE_PATH
				TYPE_OF(parent) = TYPE_LIT_PATH
				TYPE_OF(parent) = TYPE_SET_PATH
				TYPE_OF(parent) = TYPE_GET_PATH
			]
			as red-block! ALLOC_TAIL(parent)
		]
		preallocate blk size yes
	]

	make-in: func [
		parent	[red-block!]
		size 	[integer!]								;-- number of cells to pre-allocate
		return:	[red-block!]
		/local
			blk [red-block!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/make-in"]]
		
		blk: either null? parent [
			_root
		][
			assert any [
				TYPE_OF(parent) = TYPE_BLOCK			;@@ replace with ANY_BLOCK
				TYPE_OF(parent) = TYPE_PAREN
				TYPE_OF(parent) = TYPE_PATH
				TYPE_OF(parent) = TYPE_LIT_PATH
				TYPE_OF(parent) = TYPE_SET_PATH
				TYPE_OF(parent) = TYPE_GET_PATH
			]
			as red-block! ALLOC_TAIL(parent)
		]
		make-at blk size
	]
	
	push: func [
		blk [red-block!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/push"]]

		copy-cell as red-value! blk stack/push*
	]
	
	push-only*: func [
		size	[integer!]
		return: [red-block!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/push-only*"]]

		if zero? size [size: 1]
		make-at as red-block! stack/push* size
	]
	
	mold-each: func [
		blk		  [red-block!]
		buffer	  [red-string!]
		only?	  [logic!]
		all?	  [logic!]
		flat?	  [logic!]
		arg		  [red-value!]
		part 	  [integer!]
		indent	  [integer!]
		return:   [integer!]
		/local
			s	  [series!]
			head  [red-value!]
			tail  [red-value!]
			value [red-value!]
			lf?	  [logic!]
	][
		s: GET_BUFFER(blk)
		head:  s/offset + blk/head
		value: head
		tail:  s/tail
		
		lf?: off
		cycles/push blk/node
		
		while [value < tail][
			if all [OPTION?(arg) part <= 0][
				cycles/pop
				return part
			]
			depth: depth + 1
			unless flat? [
				if value/header and flag-new-line <> 0 [ ;-- new-line marker
					unless lf? [lf?: on indent: indent + 1]
					string/append-char GET_BUFFER(buffer) as-integer lf
					loop indent [string/concatenate-literal buffer "    "]
					part: part - (indent * 4 + 1) 		;-- account for lf
				]
			]
			part: actions/mold value buffer only? all? flat? arg part indent
			if positive? depth [
				string/append-char GET_BUFFER(buffer) as-integer space
				part: part - 1
			]
			depth: depth - 1
			value: value + 1
		]
		cycles/pop
		
		s: GET_BUFFER(buffer)
		if value <> head [								;-- test if not empty block
			s/tail: as cell! (as byte-ptr! s/tail) - GET_UNIT(s) ;-- remove extra white space
			part: part + 1
		]
		if lf? [
			indent: indent - 1
			string/append-char GET_BUFFER(buffer) as-integer lf
			loop indent [string/concatenate-literal buffer "    "]
			part: part - (indent * 4 + 1) 		;-- account for lf
		]
		part
	]

	compare-each: func [
		blk1	   [red-block!]							;-- first operand
		blk2	   [red-block!]							;-- second operand
		op		   [integer!]							;-- type of comparison
		return:	   [integer!]
		/local
			s1	   [series!]
			s2	   [series!]
			size1  [integer!]
			size2  [integer!]
			type1  [integer!]
			type2  [integer!]
			value1 [red-value!]
			value2 [red-value!]
			res	   [integer!]
			n	   [integer!]
			len	   [integer!]
			same?  [logic!]
	][
		same?: all [
			blk1/node = blk2/node
			blk1/head = blk2/head
		]
		if op = COMP_SAME [return either same? [0][-1]]
		if same? [return 0]
		if cycles/find? blk1/node [
			return either cycles/find? blk2/node [0][-1]
		]

		s1: GET_BUFFER(blk1)
		s2: GET_BUFFER(blk2)
		size1: (as-integer s1/tail - s1/offset) >> 4 - blk1/head
		size2: (as-integer s2/tail - s2/offset) >> 4 - blk2/head

		if size1 <> size2 [										;-- shortcut exit for different sizes
			if any [
				op = COMP_STRICT_EQUAL_WORD op = COMP_EQUAL op = COMP_FIND op = COMP_STRICT_EQUAL op = COMP_NOT_EQUAL
			][return 1]
		]

		if zero? size1 [return 0]								;-- shortcut exit for empty blocks

		value1: s1/offset + blk1/head
		value2: s2/offset + blk2/head
		len: either size1 < size2 [size1][size2]
		n: 0

		cycles/push blk1/node
		cycles/push blk2/node
		
		until [
			type1: TYPE_OF(value1)
			type2: TYPE_OF(value2)
			either any [
				type1 = type2
				all [word/any-word? type1 word/any-word? type2]
				all [											;@@ replace by ANY_NUMBER?
					any [type1 = TYPE_INTEGER type1 = TYPE_FLOAT]
					any [type2 = TYPE_INTEGER type2 = TYPE_FLOAT]
				]
			][
				res: actions/compare-value value1 value2 op
				value1: value1 + 1
				value2: value2 + 1
			][
				cycles/pop-n 2
				return SIGN_COMPARE_RESULT(type1 type2)
			]
			n: n + 1
			any [
				res <> 0
				n = len
			]
		]
		cycles/pop-n 2
		if zero? res [res: SIGN_COMPARE_RESULT(size1 size2)]
		res
	]

	;--- Actions ---
	
	make: func [
		proto	[red-block!]
		spec	[red-value!]
		type	[integer!]
		return:	[red-block!]
		/local
			size [integer!]
			int  [red-integer!]
			fl   [red-float!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/make"]]

		size: 0
		switch TYPE_OF(spec) [
			TYPE_INTEGER
			TYPE_FLOAT [
				GET_INT_FROM(size spec)
				if size <= 0 [size: 1]
				make-at proto size
				proto/header: type
				proto
			]
			TYPE_ANY_PATH
			TYPE_ANY_LIST [
				proto: clone as red-block! spec no no
				proto/header: type
				proto
			]
			TYPE_OBJECT [object/reflect as red-object! spec words/body]
			TYPE_MAP	[map/reflect as red-hash! spec words/body]
			TYPE_VECTOR [vector/to-block as red-vector! spec proto]
			default [
				fire [TO_ERROR(script bad-make-arg) datatype/push type spec]
				null
			]
		]
	]

	to: func [
		proto	[red-block!]
		spec	[red-value!]
		type	[integer!]
		return: [red-block!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/to"]]

		switch TYPE_OF(spec) [
			TYPE_OBJECT   [object/reflect as red-object! spec words/body]
			TYPE_MAP	  [map/reflect as red-hash! spec words/body]
			TYPE_VECTOR   [vector/to-block as red-vector! spec proto]
			TYPE_STRING   [lexer/scan-alt as red-value! proto as red-string! spec -1 no yes yes no null null as red-series! spec]
			TYPE_TYPESET  [typeset/to-block as red-typeset! spec proto]
			TYPE_ANY_PATH
			TYPE_ANY_LIST [proto: clone as red-block! spec no no]
			default		  [rs-append make-at proto 1 spec]
		]
		proto/header: type
		proto
	]

	form: func [
		blk		  [red-block!]
		buffer	  [red-string!]
		arg		  [red-value!]
		part 	  [integer!]
		return:   [integer!]
		/local
			s	  [series!]
			buf	  [series!]
			value [red-value!]
			tail  [red-value!]
			unit  [integer!]
			c	  [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/form"]]

		if cycles/detect? as red-value! blk buffer :part no [return part]
		
		s: GET_BUFFER(blk)
		value: s/offset + blk/head
		tail: s/tail
		c: 0
		
		cycles/push blk/node
		
		while [value < tail][
			if all [OPTION?(arg) part <= 0][
				cycles/pop
				return part
			]
			part: actions/form value buffer arg part
			value: value + 1
			
			if value < tail [
				buf:  GET_BUFFER(buffer)
				unit: GET_UNIT(buf)
				c: either buf/offset = buf/tail [0][
					string/get-char (as byte-ptr! buf/tail) - unit unit
				]

				unless any [
					c = as-integer #"^/"
					c = as-integer #"^M"
					c = as-integer #"^-"
				][
					string/append-char buf as-integer space
					part: part - 1
				]
			]
		]
		cycles/pop
		part
	]
	
	mold: func [
		blk		[red-block!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part	[integer!]
		indent	[integer!]
		return:	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/mold"]]
		
		if cycles/detect? as red-value! blk buffer :part yes [return part]
		
		unless only? [
			string/append-char GET_BUFFER(buffer) as-integer #"["
			part: part - 1
		]
		part: mold-each blk buffer no all? flat? arg part indent
		
		unless only? [
			string/append-char GET_BUFFER(buffer) as-integer #"]"
			part: part - 1
		]
		part
	]
	
	compare: func [
		blk1	   [red-block!]							;-- first operand
		blk2	   [red-block!]							;-- second operand
		op		   [integer!]							;-- type of comparison
		return:	   [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/compare"]]
		
		if TYPE_OF(blk2) <> TYPE_OF(blk1) [
			unless all [
				op = COMP_STRICT_EQUAL_WORD
				any [
					all [TYPE_OF(blk1) = TYPE_PATH TYPE_OF(blk2) = TYPE_LIT_PATH]
					all [TYPE_OF(blk2) = TYPE_PATH TYPE_OF(blk1) = TYPE_LIT_PATH]
				]
			][
				RETURN_COMPARE_OTHER
			]
		]
		compare-each blk1 blk2 op
	]
	
	eval-path: func [
		parent	[red-block!]							;-- implicit type casting
		element	[red-value!]
		value	[red-value!]
		path	[red-value!]
		case?	[logic!]
		return:	[red-value!]
		/local
			int  [red-integer!]
			set? [logic!]
			type [integer!]
			s	 [series!]
	][
		set?: value <> null
		type: TYPE_OF(element)
		either type = TYPE_INTEGER [
			int: as red-integer! element
			either set? [
				_series/poke as red-series! parent int/value value null
				value
			][
				s: GET_BUFFER(parent)
				if s/flags and flag-series-owned <> 0 [
					copy-cell as red-value! parent as red-value! object/path-parent
				]
				_series/pick as red-series! parent int/value null
			]
		][
			either set? [
				element: find parent element null no case? no no null null no no no no
				if TYPE_OF(element) = TYPE_NONE [
					fire [TO_ERROR(script bad-path-set) path element]
				]
				actions/poke as red-series! element 2 value null
				value
			][
				s: GET_BUFFER(parent)
				if s/flags and flag-series-owned <> 0 [
					copy-cell as red-value! parent as red-value! object/path-parent
				]
				either type = TYPE_WORD [
					select-word parent as red-word! element case?
				][
					select parent element null yes case? no no null null no no
				]
			]
		]
	]
	
	;--- Navigation actions ---
	
	find: func [
		blk			[red-block!]
		value		[red-value!]
		part		[red-value!]
		only?		[logic!]
		case?		[logic!]
		same?	 	[logic!]
		any?		[logic!]
		with-arg	[red-string!]
		skip		[red-integer!]
		last?		[logic!]
		reverse?	[logic!]
		tail?		[logic!]
		match?		[logic!]
		return:		[red-value!]
		/local
			s		[series!]
			s2		[series!]
			slot	[red-value!]
			slot2	[red-value!]
			beg		[red-value!]
			end		[red-value!]
			result	[red-value!]
			int		[red-integer!]
			b		[red-block!]
			dt		[red-datatype!]
			pos		[byte-ptr!]
			values	[integer!]
			step	[integer!]
			n		[integer!]
			part?	[logic!]
			op		[integer!]
			type	[integer!]
			stype	[integer!]
			ts?		[logic!]
			found?	[logic!]
			hash?	[logic!]
			table	[node!]
			hash	[red-hash!]
			any-blk? [logic!]
			key		[red-value!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/find"]]
		
		result: stack/push as red-value! blk
		hash?: TYPE_OF(blk) = TYPE_HASH
		if hash? [
			hash: as red-hash! blk
			table: hash/table
		]

		s: GET_BUFFER(blk)
		beg: s/offset + blk/head

		if any [							;-- early exit if blk is empty or at tail
			s/offset = s/tail
			all [not reverse? beg >= s/tail]
		][
			result/header: TYPE_NONE
			return result
		]
		step:  1
		part?: no
		
		if OPTION?(skip) [
			assert TYPE_OF(skip) = TYPE_INTEGER
			step: skip/value
			unless positive? step [
				fire [TO_ERROR(script out-of-range) skip]
			]
		]
		if OPTION?(part) [
			part: either TYPE_OF(part) = TYPE_INTEGER [
				int: as red-integer! part
				if int/value <= 0 [						;-- early exit if part <= 0
					result/header: TYPE_NONE
					return result
				]
				beg + int/value - 1						;-- int argument is 1-based
			][
				b: as red-block! part
				unless all [
					TYPE_OF(b) = TYPE_OF(blk)			;-- handles ANY-BLOCK!
					b/node = blk/node
				][
					ERR_INVALID_REFINEMENT_ARG(refinements/_part part)
				]
				s/offset + b/head
			]
			part?: yes
		]

		type: TYPE_OF(value)
		if type = TYPE_OBJECT [hash?: no]				;-- use block search
		any-blk?: either all [same? hash?][no][ANY_BLOCK_STRICT?(type)]
		op: either case? [COMP_STRICT_EQUAL][COMP_FIND] ;-- warning: /case <> STRICT...
		if same? [op: COMP_SAME]

		either any [
			match?
			any-blk?									;@@ we don't hash block!
			not hash?
		][
			values: either only? [0][					;-- values > 0 => series comparison mode
				either any-blk? [
					b: as red-block! value
					s2: GET_BUFFER(b)
					value: s2/offset + b/head
					(as-integer s2/tail - s2/offset) >> 4 - b/head
				][0]
			]
			if negative? values [values: 0]				;-- empty value series case

			case [
				last? [
					step: 0 - step
					slot: either part? [part][either values > 0 [s/tail - values][s/tail - 1]]
					end: s/offset
				]
				reverse? [
					step: 0 - step
					slot: either part? [part][either values > 0 [beg - values][beg - 1]]
					end: s/offset
					if slot < end [							;-- early exit if blk/head = 0
						result/header: TYPE_NONE
						return result
					]
				]
				true [
					slot: beg
					end: either part? [part + 1][s/tail]	;-- + 1 => compensate for the '>= test
				]
			]

			reverse?: any [reverse? last?]					;-- reduce both flags to one
			
			type: either type = TYPE_DATATYPE [
				dt: as red-datatype! value
				dt/value
			][-1]											;-- disable "type searching" mode
			ts?: TYPE_OF(value) = TYPE_TYPESET

			until [
				either zero? values [
					stype: TYPE_OF(slot)
					found?: case [
						positive? type [
							dt: as red-datatype! slot
							any [
								stype = type				;-- simple type comparison
								all [
									stype = TYPE_DATATYPE
									dt/value = type			;-- attempt matching a datatype! value
								]
							]
						]
						ts?  [BS_TEST_BIT_ALT(value stype)]	;-- attempt matching a typeset! value
						true [actions/compare slot value op];-- atomic comparison
					]
					if match? [slot: slot + 1]				;-- /match option returns tail of match
				][
					n: 0
					slot2: slot
					until [									;-- series comparison
						found?: actions/compare slot2 value + n op
						slot2: slot2 + 1
						n: n + 1
						any [
							not found?						;-- no match
							n = values						;-- values exhausted
							all [reverse?     slot2 <= end]	;-- block series head reached
							all [not reverse? slot2 >= end]	;-- block series tail reached
						]
					]
					if all [n < values slot2 >= end][found?: no] ;-- partial match case, make it fail
					if all [match? found?][slot: slot2]		;-- slot2 points to tail of match
				]
				slot: slot + step
				any [
					match?									;-- /match option limits to one comparison
					all [not match? found?]					;-- match found
					all [reverse? slot < end]				;-- head of block series reached
					all [not reverse? slot >= end]			;-- tail of block series reached
				]
			]
			either tail? [
				either values > 0 [slot: slot - step + values][
					if reverse? [slot: slot - step + 1]
				]
			][
				slot: slot - step							;-- compensate for extra step in loop
			]
			
			either found? [
				blk: as red-block! result
				blk/head: (as-integer slot - s/offset) >> 4	;-- just change the head position on stack
			][
				result/header: TYPE_NONE					;-- change the stack 1st argument to none.
			]
		][
			key: _hashtable/get table value hash/head step op last? reverse?
			either any [
				key = null
				all [part? key > part]
			][
				result/header: TYPE_NONE
			][
				blk: as red-block! result
				if tail? [key: key + 1]
				blk/head: (as-integer key - s/offset) >> 4	;-- just change the head position on stack
			]
		]
		result
	]
	
	select: func [
		blk		 [red-block!]
		value	 [red-value!]
		part	 [red-value!]
		only?	 [logic!]
		case?	 [logic!]
		same?	 [logic!]
		any?	 [logic!]
		with-arg [red-string!]
		skip	 [red-integer!]
		last?	 [logic!]
		reverse? [logic!]
		return:	 [red-value!]
		/local
			s	   [series!]
			p	   [red-value!]
			b	   [red-block!]
			result [red-value!]
			type   [integer!]
			offset [integer!]
	][
		result: find blk value part only? case? same? any? with-arg skip last? reverse? no no
		
		if TYPE_OF(result) <> TYPE_NONE [
			offset: either only? [1][					;-- values > 0 => series comparison mode
				type: TYPE_OF(value)
				either ANY_BLOCK_STRICT?(type) [
					b: as red-block! value
					s: GET_BUFFER(b)
					(as-integer s/tail - s/offset) >> 4 - b/head
				][1]
			]
			blk: as red-block! result
			s: GET_BUFFER(blk)
			p: s/offset + blk/head + offset
			
			either p < s/tail [
				copy-cell p result
			][
				result/header: TYPE_NONE
			]
		]
		result
	]

	put: func [
		blk		[red-block!]
		field	[red-value!]
		value	[red-value!]
		case?	[logic!]
		return:	[red-value!]
		/local
			slot  [red-value!]
			saved [red-block!]
			s	  [series!]
			hash? [logic!]
			hash  [red-hash!]
			put? chk? [logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/put"]]

		saved: blk
		hash?: TYPE_OF(blk) = TYPE_HASH
		hash: as red-hash! blk
		blk: as red-block! find blk field null no case? no no null null no no no no
		
		either TYPE_OF(blk) = TYPE_NONE [
			chk?: ownership/check as red-value! saved words/_put value rs-length? saved 1
			copy-cell field ALLOC_TAIL(blk)
			value: copy-cell value ALLOC_TAIL(blk)
			if hash? [
				_hashtable/put hash/table value - 1
				_hashtable/put hash/table value
			]
		][
			s: GET_BUFFER(blk)
			slot: s/offset + blk/head + 1
			chk?: ownership/check as red-value! blk words/_put value blk/head + 1 1
			either slot >= s/tail [
				put?: yes
				slot: alloc-tail s
				slot/header: -1
			][
				put?: 0 <> actions/compare-value slot value COMP_FIND
			]
			if put? [
				copy-cell value slot
				if hash? [_hashtable/put hash/table slot]
			]
			ownership/check as red-value! blk words/_put-ed value blk/head + 1 1
		]
		value
	]

	compare-value: func [								;-- Compare function return integer!
		value1   [red-value!]
		value2   [red-value!]
		op		 [integer!]
		flags	 [integer!]
		return:  [integer!]
		/local
			offset	[integer!]
			res		[integer!]
			temp	[red-value!]
			action-compare
	][
		#if debug? = yes [if verbose > 0 [print-line "block/compare-value"]]

		offset: flags >>> 1
		value1: value1 + offset
		value2: value2 + offset
		if flags and sort-reverse-mask = sort-reverse-mask [
			temp: value1 value1: value2 value2: temp
		]
		action-compare: DISPATCH_COMPARE(value1)

		res: action-compare value1 value2 op
		if res = -2 [res: TYPE_OF(value1) - TYPE_OF(value2)]
		res
	]

	compare-call: func [								;-- Wrap red function!
		value1   [red-value!]
		value2   [red-value!]
		fun		 [integer!]
		flags	 [integer!]
		return:  [integer!]
		/local
			res  [red-value!]
			bool [red-logic!]
			int  [red-integer!]
			d    [red-float!]
			f	 [red-function!]
			all? [logic!]
			num  [integer!]
			blk1 [red-block!]
			blk2 [red-block!]
			v1	 [red-value!]
			v2	 [red-value!]
			s1   [series!]
			s2   [series!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/compare-call"]]

		f: as red-function! fun
		stack/mark-func words/_body	f/ctx				;@@ find something more adequate

		either flags and sort-reverse-mask = 0 [
			v2: stack/push value2
			v1: stack/push value1
		][
			v1: stack/push value1
			v2: stack/push value2
		]

		all?: flags and sort-all-mask = sort-all-mask
		num: flags >>> 2
		if all [all? num > 0][
			if null? compare-arg-a [
				compare-arg-a: ALLOC_TAIL(root)
				compare-arg-b: ALLOC_TAIL(root)
				make-at as red-block! compare-arg-a 1
				make-at as red-block! compare-arg-b 1
			]
			blk1: as red-block! copy-cell compare-arg-a v1
			blk2: as red-block! copy-cell compare-arg-b v2
			s1: GET_BUFFER(blk1)
			s2: GET_BUFFER(blk2)
			s1/offset: value1
			s2/offset: value2
			s1/tail: value1 + num
			s2/tail: value2 + num
		]

		_function/call f global-ctx				;FIXME: hardcoded origin context
		stack/unwind
		stack/pop 1

		if all [all? num > 0][					;-- reset series!, make GC happy
			s1/offset: as cell! (s1 + 1)
			s1/tail: s1/offset
			s2/offset: as cell! (s2 + 1)
			s2/tail: s2/offset
		]

		res: stack/top
		switch TYPE_OF(res) [
			TYPE_LOGIC [
				bool: as red-logic! res
				either bool/value [1][-1]
			]
			TYPE_INTEGER [
				int: as red-integer! res
				int/value
			]
			TYPE_FLOAT [
				d: as red-float! res
				case [
					d/value > 0.0 [1]
					d/value < 0.0 [-1]
					true [0]
				]
			]
			TYPE_NONE [-1]
			default   [1]
		]
	]

	sort: func [
		blk			[red-block!]
		case?		[logic!]
		skip		[red-integer!]
		comparator	[red-function!]
		part		[red-value!]
		all?		[logic!]
		reverse?	[logic!]
		stable?		[logic!]
		return:		[red-block!]
		/local
			s		[series!]
			head	[red-value!]
			cmp		[integer!]
			len		[integer!]
			len2	[integer!]
			step	[integer!]
			int		[red-integer!]
			blk2	[red-block!]
			op		[integer!]
			flags	[integer!]
			offset	[integer!]
			saved	[logic!]
			chk?	[logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/sort"]]

		step: 1
		flags: 0
		s: GET_BUFFER(blk)
		head: s/offset + blk/head
		if head = s/tail [return blk]					;-- early exit if nothing to sort
		len: rs-length? blk

		if OPTION?(part) [
			len2: either TYPE_OF(part) = TYPE_INTEGER [
				int: as red-integer! part
				if int/value <= 0 [return blk]			;-- early exit if part <= 0
				int/value
			][
				blk2: as red-block! part
				unless all [
					TYPE_OF(blk2) = TYPE_OF(blk)		;-- handles ANY-STRING!
					blk2/node = blk/node
				][
					ERR_INVALID_REFINEMENT_ARG(refinements/_part part)
				]
				blk2/head - blk/head
			]
			if len2 < len [
				len: len2
				if negative? len2 [
					len2: 0 - len2
					blk/head: blk/head - len2
					len: either negative? blk/head [blk/head: 0 0][len2]
					head: head - len
				]
			]
		]

		if OPTION?(skip) [
			assert TYPE_OF(skip) = TYPE_INTEGER
			step: skip/value
			if any [
				step <= 0
				len % step <> 0
				step > len
			][
				ERR_INVALID_REFINEMENT_ARG(refinements/_skip skip)
			]
			if step > 1 [len: len / step]
		]

		if reverse? [flags: flags or sort-reverse-mask]
		op: either case? [COMP_CASE_SORT][COMP_SORT]
		cmp: as-integer :compare-value

		if OPTION?(comparator) [
			switch TYPE_OF(comparator) [
				TYPE_FUNCTION [
					if all [all? OPTION?(skip)] [
						flags: flags or sort-all-mask
						flags: step << 2 or flags
					]
					cmp: as-integer :compare-call
					op: as-integer comparator
				]
				TYPE_INTEGER [
					int: as red-integer! comparator
					offset: int/value
					if any [offset < 1 offset > step][
						fire [
							TO_ERROR(script out-of-range)
							comparator
						]
					]
					flags: offset - 1 << 1 or flags
				]
				default [
					ERR_INVALID_REFINEMENT_ARG(refinements/compare comparator)
				]
			]
		]
		chk?: ownership/check as red-value! blk words/_sort null blk/head 0
		saved: collector/active?
		collector/active?: no							;-- turn off GC
		either stable? [
			_sort/mergesort as byte-ptr! head len step * (size? red-value!) op flags cmp
		][
			_sort/qsort as byte-ptr! head len step * (size? red-value!) op flags cmp
		]
		collector/active?: saved
		if chk? [ownership/check as red-value! blk words/_sorted null blk/head 0]
		blk
	]
		
	;--- Modifying actions ---
	
	insert: func [
		blk		  [red-block!]
		value	  [red-value!]
		part-arg  [red-value!]
		only?	  [logic!]
		dup-arg	  [red-value!]
		append?	  [logic!]
		return:	  [red-value!]
		/local
			src		[red-block!]
			cell	[red-value!]
			limit	[red-value!]
			head	[red-value!]
			hash	[red-hash!]
			table	[node!]
			int		[red-integer!]
			b		[red-block!]
			s		[series!]
			h		[integer!]
			cnt		[integer!]
			part	[integer!]
			size	[integer!]
			slots	[integer!]
			index	[integer!]
			values?	[logic!]
			tail?	[logic!]
			hash?	[logic!]
			chk?	[logic!]
			action	[red-word!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/insert"]]
		
		cnt:  1
		part: -1
		hash?: TYPE_OF(blk) = TYPE_HASH
		if hash? [
			hash: as red-hash! blk
			table: hash/table
		]

		values?: all [
			not only?									;-- /only support
			any [
				TYPE_OF(value) = TYPE_BLOCK				;@@ replace it with: typeset/any-block?
				TYPE_OF(value) = TYPE_PATH				;@@ replace it with: typeset/any-block?
				TYPE_OF(value) = TYPE_GET_PATH			;@@ replace it with: typeset/any-block?
				TYPE_OF(value) = TYPE_SET_PATH			;@@ replace it with: typeset/any-block?
				TYPE_OF(value) = TYPE_LIT_PATH			;@@ replace it with: typeset/any-block?
				TYPE_OF(value) = TYPE_PAREN				;@@ replace it with: typeset/any-block?
				TYPE_OF(value) = TYPE_HASH				;@@ replace it with: typeset/any-block?	
			]
		]

		if all [OPTION?(part-arg) values?][
			part: either TYPE_OF(part-arg) = TYPE_INTEGER [
				int: as red-integer! part-arg
				int/value
			][
				b: as red-block! part-arg
				src: as red-block! value
				unless all [
					TYPE_OF(b) = TYPE_OF(src)
					b/node = src/node
				][
					ERR_INVALID_REFINEMENT_ARG(refinements/_part part-arg)
				]
				b/head - src/head
			]
		]

		if OPTION?(dup-arg) [
			int: as red-integer! dup-arg
			cnt: int/value
			if negative? cnt [return as red-value! blk]
		]
		
		size: either values? [
			src: as red-block! value
			rs-length? src
		][
			1
		]
		if any [negative? part part > size][part: size] ;-- truncate if off-range part value
		
		s: GET_BUFFER(blk)
		if s/offset + blk/head > s/tail [				;-- Past-end index adjustment
			blk/head: (as-integer s/tail - s/offset) >> 4
		]
		h: blk/head
		tail?: any [(s/offset + h = s/tail) append?]
		slots: part * cnt
		index: either append? [
			action: words/_append
			(as-integer s/tail - s/offset) >> 4
		][
			action: words/_insert
			h
		]
		chk?: ownership/check as red-value! blk action value index part

		unless tail? [									;TBD: process head? case separately
			size: as-integer s/tail + slots - s/offset
			if size > s/size [s: expand-series s size * 2]
			head: s/offset + h
			move-memory									;-- make space
				as byte-ptr! head + slots
				as byte-ptr! head
				as-integer s/tail - head

			if hash? [
				_hashtable/refresh table slots h (as-integer s/tail - head) >> 4 yes
			]
			s/tail: s/tail + slots
		]

		while [not zero? cnt][							;-- /dup support
			either values? [
				s: GET_BUFFER(src)
				cell: s/offset + src/head
				limit: cell + part						;-- /part support

				either tail? [
					while [cell < limit][				;-- multiple values case
						copy-cell cell ALLOC_TAIL(blk)
						cell: cell + 1
					]
				][
					while [cell < limit][				;-- multiple values case
						copy-cell cell head
						head: head + 1
						cell: cell + 1
					]
				]
			][											;-- single value case
				either tail? [
					copy-cell value ALLOC_TAIL(blk)
				][
					copy-cell value head
					head: head + 1
				]
			]
			cnt: cnt - 1
		]

		if hash? [
			s: GET_BUFFER(blk)
			cell: either tail? [s/tail - slots][s/offset + h]
			loop slots [
				_hashtable/put table cell
				cell: cell + 1
			]
		]
		if chk? [
			action: either append? [words/_appended][words/_inserted]
			ownership/check as red-value! blk action value index part
		]
		either append? [blk/head: 0][
			blk/head: h + slots
			s: GET_BUFFER(blk)
			if s/offset + blk/head > s/tail [			;-- check for past-end caused by object event
				blk/head: (as-integer s/tail - s/offset) >> 4 ;-- adjust offset to series' tail
			]
		]
		as red-value! blk
	]

	take: func [
		blk	    	[red-block!]
		part-arg	[red-value!]
		deep?		[logic!]
		last?		[logic!]
		return:		[red-value!]
		/local
			s		[series!]
			slot	[red-value!]
			type	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/take"]]

		blk: as red-block! _series/take blk part-arg deep? last?
		s: GET_BUFFER(blk)

		if deep? [
			slot: s/offset
			until [
				type: TYPE_OF(slot)
				if ANY_SERIES?(type) [
					actions/copy
						as red-series! slot
						slot						;-- overwrite the slot value
						null
						yes
						null
				]
				slot: slot + 1
				slot >= s/tail
			]
		]

		if all [									;-- flatten block
			not OPTION?(part-arg)
			1 = _series/get-length blk yes
		][
			copy-cell as cell! s/offset as cell! blk
		]
		as red-value! blk
	]

	swap: func [
		blk1	   [red-block!]
		blk2	   [red-block!]
		return:	   [red-block!]
		/local
			s		[series!]
			i		[integer!]
			tmp		[integer!]
			h1		[int-ptr!]
			h2		[int-ptr!]
			type1	[integer!]
			type2	[integer!]
			hash	[red-hash!]
			table	[node!]
			chk? chk2? [logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/swap"]]

		type1: TYPE_OF(blk1)
		type2: TYPE_OF(blk2)
		if all [
			type2 <> TYPE_BLOCK
			type2 <> TYPE_HASH
		][ERR_EXPECT_ARGUMENT(type2 2)]

		s: GET_BUFFER(blk1)
		h1: as int-ptr! s/offset + blk1/head
		if s/tail = as red-value! h1 [return blk1]		;-- early exit if nothing to swap

		s: GET_BUFFER(blk2)
		h2: as int-ptr! s/offset + blk2/head
		if s/tail = as red-value! h2 [return blk1]		;-- early exit if nothing to swap

		chk?:  ownership/check as red-value! blk1 words/_swap null blk1/head 1
		chk2?: ownership/check as red-value! blk2 words/_swap null blk2/head 1

		i: 0
		until [
			tmp: h1/value
			h1/value: h2/value
			h2/value: tmp
			h1: h1 + 1
			h2: h2 + 1
			i:	i + 1
			i = 4
		]

		if type1 = TYPE_HASH [
			hash: as red-hash! blk1
			h1: h1 - 4
			_hashtable/delete hash/table as red-value! h1
			_hashtable/put hash/table as red-value! h1
		]
		if type2 = TYPE_HASH [
			hash: as red-hash! blk2
			h2: h2 - 4
			_hashtable/delete hash/table as red-value! h2
			_hashtable/put hash/table as red-value! h2
		]
		if chk?  [ownership/check as red-value! blk1 words/_swaped null blk1/head 1]
		if chk2? [ownership/check as red-value! blk2 words/_swaped null blk2/head 1]
		blk1
	]

	trim: func [
		blk			[red-block!]
		head?		[logic!]
		tail?		[logic!]
		auto?		[logic!]
		lines?		[logic!]
		all?		[logic!]
		with-arg	[red-value!]
		return:		[red-series!]
		/local
			s		[series!]
			value	[red-value!]
			cur		[red-value!]
			chk?	[logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/trim"]]

		chk?: ownership/check as red-value! blk words/_trim null blk/head 0
		s: GET_BUFFER(blk)
		value: s/offset + blk/head
		cur: value

		while [value < s/tail][
			if TYPE_OF(value) <> TYPE_NONE [
				unless value = cur [copy-cell value cur]
				cur: cur + 1
			]
			value: value + 1
		]
		s/tail: cur
		if chk? [ownership/check as red-value! blk words/_trimmed null blk/head 0]
		as red-series! blk
	]

	;--- Misc actions ---
	
	copy: func [
		blk	    	[red-block!]
		new			[red-block!]
		arg			[red-value!]
		deep?		[logic!]
		types		[red-value!]
		return:		[red-series!]
		/local
			s		[series!]
			end		[red-value!]
			node	[node!]
			type	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "block/copy"]]

		node: blk/node									;-- save node before slot is copied
		new: as red-block! _series/copy as red-series! blk as red-series! new arg deep? types
		if deep? [
			if cycles/find? node [cycles/reset fire [TO_ERROR(internal no-cycle)]]
			if TYPE_HASH = TYPE_OF(blk) [new/header: TYPE_BLOCK]
			cycles/push blk/node
			s: GET_BUFFER(new)
			arg: s/offset
			end: s/tail
			while [arg < end][
				type: TYPE_OF(arg)
				if ANY_SERIES?(type) [
					actions/copy 
						as red-series! arg
						arg						;-- overwrite the arg value
						null
						yes
						null
				]
				arg: arg + 1
			]
			cycles/pop
		]
		
		as red-series! new
	]

	do-set-op: func [
		case?	 [logic!]
		skip-arg [red-integer!]
		op		 [integer!]
		return:  [red-block!]
		/local
			blk1	[red-block!]
			blk2	[red-block!]
			hs		[red-hash!]
			new		[red-block!]
			value	[red-value!]
			tail	[red-value!]
			key		[red-value!]
			comp-op [integer!]
			i		[integer!]
			n		[integer!]
			s		[series!]
			len		[integer!]
			step	[integer!]
			table	[node!]
			hash	[node!]
			check?	[logic!]
			invert? [logic!]
			both?	[logic!]
			find?	[logic!]
			append?	[logic!]
			blk?	[logic!]
			hash?	[logic!]
			saved	[logic!]
	][
		step: 1
		if OPTION?(skip-arg) [
			assert TYPE_OF(skip-arg) = TYPE_INTEGER
			step: skip-arg/value
			if step <= 0 [
				ERR_INVALID_REFINEMENT_ARG(refinements/_skip skip-arg)
			]
		]

		find?: yes both?: no check?: no invert?: no
		if op = OP_UNION	  [both?: yes]
		if op = OP_INTERSECT  [check?: yes]
		if op = OP_EXCLUDE	  [check?: yes invert?: yes]
		if op = OP_DIFFERENCE [both?: yes check?: yes invert?: yes]

		blk1: as red-block! stack/arguments
		blk2: blk1 + 1
		len: rs-length? blk1
		if op = OP_UNION [len: len + rs-length? blk2]
		if zero? len [len: 1]
		new: make-at as red-block! stack/push* len
		table: _hashtable/init len new HASH_TABLE_HASH 1
		hs: as red-hash! new
		hs/header: TYPE_HASH
		hs/table: table
		n: 2
		hash: null
		blk?: yes
		hash?: TYPE_OF(blk1) = TYPE_HASH
		if all [not hash? op <> OP_UNIQUE][hash?: TYPE_OF(blk2) = TYPE_HASH]

		comp-op: either case? [COMP_STRICT_EQUAL][COMP_EQUAL]
		saved: collector/active?
		collector/active?: no
		until [
			s: GET_BUFFER(blk1)
			value: s/offset + blk1/head
			tail: s/tail

			if check? [
				hash: either TYPE_OF(blk2) = TYPE_HASH [
					blk?: no
					hs: as red-hash! blk2
					hs/table
				][
					if all [blk? hash <> null] [_hashtable/destroy hash]
					blk?: yes
					_hashtable/init rs-length? blk2 blk2 HASH_TABLE_HASH 1
				]
			]

			while [value < tail] [			;-- iterate over first series
				append?: no
				if check? [
					find?: null <> _hashtable/get hash value 0 step comp-op no no
					if invert? [find?: not find?]
				]
				if all [
					find?
					null = _hashtable/get table value 0 step comp-op no no
				][
					append?: yes
					_hashtable/put table rs-append new value
				]

				i: 1
				while [
					value: value + 1
					all [value < tail i < step]
				][
					i: i + 1
					if append? [
						key: rs-append new value
						if hash? [_hashtable/put table key]
					]
				]
			]

			either both? [					;-- iterate over second series?
				blk1: blk2
				blk2: as red-block! stack/arguments
				n: n - 1
			][n: 0]
			zero? n
		]
		collector/active?: saved

		either hash? [
			hs: as red-hash! blk2
			hs/header: TYPE_HASH
			hs/table: table
		][
			_hashtable/destroy table
		]
		if all [check? blk?][_hashtable/destroy hash]
		blk1/node: new/node
		blk1/head: 0
		stack/pop 1
		blk1
	]

	init: does [
		datatype/register [
			TYPE_BLOCK
			TYPE_SERIES
			"block!"
			;-- General actions --
			:make
			INHERIT_ACTION	;random
			INHERIT_ACTION	;reflect
			:to
			:form
			:mold
			:eval-path
			null			;set-path
			:compare
			;-- Scalar actions --
			null			;absolute
			null			;add
			null			;divide
			null			;multiply
			null			;negate
			null			;power
			null			;remainder
			null			;round
			null			;subtract
			null			;even?
			null			;odd?
			;-- Bitwise actions --
			null			;and~
			null			;complement
			null			;or~
			null			;xor~
			;-- Series actions --
			null			;append
			INHERIT_ACTION	;at
			INHERIT_ACTION	;back
			INHERIT_ACTION	;change
			INHERIT_ACTION	;clear
			:copy
			:find
			INHERIT_ACTION	;head
			INHERIT_ACTION	;head?
			INHERIT_ACTION	;index?
			:insert
			INHERIT_ACTION	;length?
			INHERIT_ACTION	;move
			INHERIT_ACTION	;next
			INHERIT_ACTION	;pick
			INHERIT_ACTION	;poke
			:put
			INHERIT_ACTION	;remove
			INHERIT_ACTION	;reverse
			:select
			:sort
			INHERIT_ACTION	;skip
			:swap
			INHERIT_ACTION	;tail
			INHERIT_ACTION	;tail?
			:take
			:trim
			;-- I/O actions --
			null			;create
			null			;close
			null			;delete
			INHERIT_ACTION	;modify
			null			;open
			null			;open?
			null			;query
			null			;read
			null			;rename
			null			;update
			null			;write
		]
	]
]
