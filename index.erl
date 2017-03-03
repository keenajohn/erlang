-module(index).
-export([get_file_contents/1, show_file_contents/1, show_index/1, create_index/1,pages_to_ranges/1,get_range/1 ]).

% Used to read a file into a list of lines.
% Example files available in:
%   gettysburg-address.txt (short)
%   dickens-christmas.txt  (long)
  

% Get the contents of a text file into a list of lines.
% Each line has its trailing newline removed.

get_file_contents(Name) ->
    {ok,File} = file:open(Name,[read]),
    Rev = get_all_lines(File,[]),
    lists:reverse(Rev).

% Auxiliary function for get_file_contents.
% Not exported.

get_all_lines(File,Partial) ->
    case io:get_line(File,"") of
        eof -> file:close(File),
               Partial;
        Line -> {Strip,_} = lists:split(length(Line)-1,Line),
                get_all_lines(File,[Strip|Partial])
    end.

% Show the contents of a list of strings.
% Can be used to check the results of calling get_file_contents.

show_file_contents([L|Ls]) ->
    io:format("~s~n",[L]),
    show_file_contents(Ls);
show_file_contents([]) ->
    ok.    

show_ranges([[X,Y]|[]]) ->
    io:format("[~B,~B]", [X,Y]);
show_ranges([[X,Y]|Xs]) ->
    io:format("[~B,~B],", [X,Y]),
    show_ranges(Xs);
show_ranges([]) ->
    ok.    
    
show_index([{WORD, RANGES}|ENTRIES]) ->
    io:format("~15s : ", [WORD]),
    show_ranges(RANGES),
    io:format("~n"),
    show_index(ENTRIES);
show_index([]) ->
    ok.

% Indexing a file
% The aim of this exercise is to index a text file, by line number. We can think of the input being a list of text strings, and below we’ve provided an outline Erlang module that reads text files into this format, as well as a couple of example files to process.
%
% The output of the main function should be a list of entries consisting of a word and a list of the ranges of lines on which it occurs.
% 
% For example, the entry
% 
% { "foo" , [{3,5},{7,7},{11,13}] }
% 
% means that the word "foo" occurs on lines 3, 4, 5, 7, 11, 12 and 13 in the file.
% 
% To take the problem further, you might like to think about these ways of refining the solution.
% 
% - Removing all short words (e.g. words of length less than 3) or all common words (you‘ll have to think about how to define these).
% 
% - Sorting the output so that the words occur in lexicographic order.
% 
% - Normalising the words so that capitalised ("Foo") and non capitalised versions ("foo") of a word are identified.
% 
% - Normalising so that common endings, plurals etc. identified.
% 
% - (Harder) Thinking how you could make the data representation more efficient than the one you first chose. This might be efficient for lookup only, or for both creation and lookup.
%
% - Can you think of other ways that you might extend your solution?
%   ANSWER: Count the number of occurances on each line. Provide function to return the index entry when given a word.

create_index(Name) ->
    % read from file into list of lines
    LINES = get_file_contents(Name),
    % parse words from each line. need word and line number
    P = fun(LINE, {N,WORDS}) -> {N+1, WORDS ++ get_words(LINE, N)} end,
    {_NUMLINES, INDEX_V1}=lists:foldl(P, {1,[]}, LINES),
    INDEX_V2=remove_empty_words(INDEX_V1),
    INDEX_V3=remove_blacklisted_words(INDEX_V2),
    INDEX_V4=sort_entries(INDEX_V3),
    INDEX=combine_entries(INDEX_V4),
    show_index(INDEX).

% Given a line of text, return the first word.
% The word is normalised to lower case.
get_word(LINE) ->
    get_word([], LINE).
    
get_word(WORD, []) ->
    string:to_lower(WORD);
get_word(WORD, [CHAR|CHARs]) ->
    case lists:member(CHAR, " .,;/\\-?!") of 
        true ->
            string:to_lower(WORD);
        false ->
            get_word(lists:append(WORD,[CHAR]), CHARs)
    end.

% given a line of text and the line number, return a list of index entries: [{"word", [N,N]}, ...]
get_words([], _N) ->
    [];
get_words([_WORD|[]], _N) ->
    [];
get_words(LINE, N) ->
    WORD=get_word(LINE),
    case length(LINE) >= (length(WORD)+1) of
        true ->
            {_WORD_WITH_SPACE, REST_OF_LINE} = lists:split(length(WORD)+1,LINE);
        false ->
            REST_OF_LINE = []
    end,
    [{WORD,[N,N]}|get_words(REST_OF_LINE, N)].
    
% return an index in which all elements with empty words are removed
remove_empty_words(INDEX) ->
    lists:filter(fun(ENTRY)-> not_empty_word(ENTRY) end, INDEX).
    
% given an index entry, return true if the word is not an empty list
not_empty_word({WORD, _PAGES}) ->
    WORD/=[].

% return an index in which all elements with blacklisted words are removed
remove_blacklisted_words(INDEX) ->
    lists:filter(fun(ENTRY)-> not_blacklisted(ENTRY) end, INDEX).

% given an index entry, return true if the word is not blacklisted
not_blacklisted({WORD, _PAGES}) ->
    lists:member(WORD,["a","the","to","with","is","are","be","was","were","these","those","who","what","where","why","how","which"]) /= true.

sort_entries(INDEX) ->
    lists:sort(fun({WORD_A, _PAGES_A}, {WORD_B, _PAGES_B}) -> WORD_A < WORD_B end, INDEX).

combine_entries([]) ->
    [];
combine_entries([{WORD_A, PAGES_A}|[]]) ->
    [{WORD_A, pages_to_ranges(lists:sort(PAGES_A))}];
combine_entries([{WORD_A, PAGES_A}|[{WORD_B, PAGES_B}|ENTRIES]]) ->
    case WORD_A == WORD_B of
        true ->
            % combine the entries
            combine_entries([{WORD_A, lists:flatten([PAGES_A|PAGES_B])}|ENTRIES]);
        false ->
            [{WORD_A, pages_to_ranges(lists:sort(PAGES_A))}|combine_entries([{WORD_B, PAGES_B}|ENTRIES])]
    end.

% convert a list of line numbers to a list of line ranges
% [1,1,2,2,4,4,5,5,5,5,7,7] -> [[1,2],[4,5],[7,7]]
pages_to_ranges(LINES) ->
    SORTED_LINES = lists:usort(LINES),
    get_ranges(SORTED_LINES).

get_ranges([]) ->
    [];
get_ranges([X]) ->
    [[X,X]];
get_ranges([X|Xs]) ->
    FIRST_RANGE=get_range([X|Xs]),
    {_LIST1,LIST2}=lists:partition(fun(PAGE) -> PAGE =< lists:nth(2,FIRST_RANGE) end, Xs),
    [FIRST_RANGE|get_ranges(LIST2)].

% Given a an ordered list of line numbers, return the first range.
get_range(LINES) ->
    get_range(hd(LINES), tl(LINES)).
    
get_range([], _) ->
    [];
get_range(RANGE_START, []) ->
    [RANGE_START, RANGE_START];
get_range(RANGE_START, [LINE|LINEs]) ->
    case (LINE - RANGE_START) > 1 of
        true ->
            [RANGE_START, RANGE_START];
        false ->
            [RANGE_START | tl(get_range(LINE, LINEs))]
    end.
