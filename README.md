# check-synonyms
Synonym validation

This routine groups synonyms (or antonyms) into collections. Each reference found is grouped in a collection. 

Each is further analyzed to determine:
1.	Do any matching lexemes/headwords exist in the file? (If so, Ref Fnd = "Y").
2.	Is the reference reciprocated under a lexeme/headword entry? (If so, Reciprocal = Headword.Homograph of the reciprocating entry.)
3.	Is the reference ambiguous? (If so, Ambiguous = "Y".) It is ambiguous if:
	a.	It refers to multiple homograph entries with no reciprocating entry - OR - 
	b.	It refers to multiple homograph entries with multiple reciprocating entries.    

The output report is intended to be read by a spreadsheet. Because there are commas in some primary entries, it is delimited by 
octothorpe "#". It includes these columns:
1.	Collection: A number assigned to group the words together. All words in a collection should mean the same thing. 
2.	Lexeme: The lexeme/headword under which the reference is found. 
3.	Sense: (Proposed) The sense and sub-sense under which the reference is found.
4.	Synonym: (Antonym proposed) The original value of the reference. 
5.	Ref Fnd: A Y/N switch indicating whether any matching lexeme/headword references were found.  
6.	Reciprocal: The value of the lexeme/headword, including any homograph number, under which a reciprocal reference was found.
7.	Ambiguous: A Y/N switch indicating whether the reference is ambiguous.
8.	Proposed Update: (Proposed) A report of showing the reference with a proposed update to the sfm including 
	homograph, sense, and sub-sense values.
   
   
Assumptions:
- Homographs are present and correct.
- Sense/sub-sense numbering begins with 1 and is correct.


