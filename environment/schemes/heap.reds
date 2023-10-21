Red/System []

#if all [OS = 'Windows debug? = yes] [
𝐇eap!: alias struct! [
	data          [byte-ptr!]
	size          [integer!]
	overhead      [byte!]
	index         [byte!]
	flags         [integer!]
]

𝐌emory: context [

	;######################################### kernel ##
	;
	; ██   ██ ███████  █████  ██████   █████  ██████  ██
	; ██   ██ ██      ██   ██ ██   ██ ██   ██ ██   ██ ██
	; ███████ █████   ███████ ██████  ███████ ██████  ██
	; ██   ██ ██      ██   ██ ██      ██   ██ ██      ██
	; ██   ██ ███████ ██   ██ ██      ██   ██ ██      ██
	;

	;--------------------------------- KERNEL_LIBRARY --
	;

	#import ["kernel32.dll" stdcall [

		GetProcessHeap: "GetProcessHeap" [
			return:                 [byte-ptr!]
		]

		HeapAlloc: "HeapAlloc" [
			heap                    [byte-ptr!]
			flags                   [integer!]
			bytes                   [integer!]
			return:                 [byte-ptr!]
		]

		HeapCreate: "HeapCreate" [
			options                 [integer!]
			initial                 [integer!]
			maximum                 [integer!]
			return:                 [byte-ptr!]
		]

		HeapDestroy: "HeapDestroy" [
			heap                    [byte-ptr!]
			return:                 [integer!]
		]

		HeapFree: "HeapFree" [
			heap                    [byte-ptr!]
			flags                   [integer!]
			mem                     [byte-ptr!]
			return:                 [integer!]
		]

		HeapValidate: "HeapValidate" [
			heap                    [byte-ptr!]
			flags                   [integer!]
			mem                     [byte-ptr!]
			return:                 [integer!]
		]

		HeapWalk: "HeapWalk" [
			heap                    [byte-ptr!]
			entry                   [byte-ptr!]
			return:                 [integer!]
		]

		Sleep: "Sleep" [
			millisecs               [integer!]
		]

	]] ;#import

	Heap: declare byte-ptr!
	Heap: null
]]

𝐀llocate: func [
	bytes           [integer!]
	return:         [byte-ptr!]
][
#either all [OS = 'Windows debug? = yes] [
	if zero? 𝐌emory/HeapValidate 𝐌emory/Heap 0 null [
		fire [TO_ERROR(internal no-memory)]
	]

	return 𝐌emory/HeapAlloc 𝐌emory/Heap 8 bytes                                ;-- HEAP_ZERO_MEMORY
][
	return allocate bytes
]]

𝐅ree: func [
	memory          [byte-ptr!]
	return:         [integer!]
][
#either all [OS = 'Windows debug? = yes] [
	if zero? 𝐌emory/HeapValidate 𝐌emory/Heap 0 null [
		fire [TO_ERROR(internal wrong-mem)]
	]

	return 𝐌emory/HeapFree 𝐌emory/Heap 0 memory
][
	free memory
	return 0
]]

𝐇eapCreate: func [] [#either all [OS = 'Windows debug? = yes] [
	𝐌emory/Heap: 𝐌emory/HeapCreate 0 0 0
][]]

𝐇eapDestroy: func [] [#either all [OS = 'Windows debug? = yes] [
	𝐌emory/HeapDestroy 𝐌emory/Heap
	𝐌emory/Heap: null
][]]

𝐕alidate: func [] [#either all [OS = 'Windows debug? = yes][
	if zero? 𝐌emory/HeapValidate 𝐌emory/Heap 0 null [
		fire [TO_ERROR(script past-end)]
	]
][]]

𝐕alidBefore: func [] [#either all [OS = 'Windows debug? = yes] [
	if zero? 𝐌emory/HeapValidate 𝐌emory/Heap 0 null [
		print ["*** heap validity pre-condition failed" lf]
		fire [TO_ERROR(script past-end)]
	]
][]]

𝐕alidAfter: func [] [#either all [OS = 'Windows debug? = yes] [
	if zero? 𝐌emory/HeapValidate 𝐌emory/Heap 0 null [
		print ["*** heap validity post-condition failed" lf]
		fire [TO_ERROR(script past-end)]
	]
][]]

𝐇eap: #either all [OS = 'Windows debug? = yes] [func [
	/local
		i           [integer!]
		rc          [integer!]
		step        [𝐇eap!]
][
	step:           declare 𝐇eap!
	step/data:      null
	step/size:      0
	step/overhead:  as byte! 0
	step/index:     as byte! 0
	step/flags:     0

	rc: 0
	i:  0

	while [true] [
		rc: 𝐌emory/HeapWalk 𝐌emory/Heap as byte-ptr! step
		if zero? rc [break]

		i: i + 1
		print [i tab step/data space step/size tab as integer! step/overhead tab as integer! step/index tab step/flags tab]

		unless zero? (step/flags >> 8 and 0001h) [print ["region"      space]]
		unless zero? (step/flags >> 8 and 0002h) [print ["uncommitted" space]]
		unless zero? (step/flags >> 8 and 0004h) [print ["busy"        space]]
		unless zero? (step/flags >> 8 and 0010h) [print ["moveable"    space]]
		unless zero? (step/flags >> 8 and 0020h) [print ["ddeshare"    space]]
		print [lf]
	]
]][
	func [] []
]
