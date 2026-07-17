program TypingTrain;
uses crt;
{$H+}
{$I-}

const
    InputFieldHeight = 10;
    InputFieldWidth = 50; 
    {Help info padding from (0, 0)} 
    HelpInfoBarX = 1;
    HelpInfoBarY = 2;
    {Space reserved for service messages next to the input field}
    ServiceAreaWidth = 2;
    ServiceAreaHeight = 5; 
    TerminalMinSizeWidth = InputFieldWidth + ServiceAreaWidth;
    TerminalMinSizeHeight = InputFieldHeight + ServiceAreaHeight;
    ErrorCountBarPaddingX = 0;
    ErrorCountBarPaddingY = 2;
    InputFieldBorderSymb = '#';
    EnterCharCode = 13;
    EscapeCharCode = 27;    
    SpaceCharCode = 32;
    LineFeedCharCode = 10;  
    BackSpaceCharCode = 8;
    NoParamErrorMsg = 'Please specify a filename';
    OpenFileErrorMsg = 'Could not open the file';
    TerminalSizeErrorMsg = 'Terminal size is too small';
    EmptyListErrorMsg = 'The input file is empty or contains no Latin text';
    ChangeTextMsg = 'To change text press';
    ExitMsg = 'To exit press'; 
    {Typing text padding from upper left corner} 
    TypingTextPaddingX = 2;
    TypingTextPaddingY = 2;
    MaxTypingTextLen = InputFieldWidth - (TypingTextPaddingX * 2);
    {Errors bar padding from upper left field corner}
    ErrorCountBarMsg = 'Errors: ';
    NoKeyPressDelayMs = 5;
    {Delay after finishing text line}
    TextEndDelayMs = 100;

    
type
    ListOfWordsElemPtr = ^ListOfWordsElem;
    ListOfWordsElem = record
        word: string;
        index: integer;
        NextWordPtr: ListOfWordsElemPtr;
    end;
    {Pointers on first and last elem of list}
    ListOfWordsPtr = record
        first: ListOfWordsElemPtr;
        last: ListOfWordsElemPtr; 
    end;
    CharFile = file of char;
    
procedure GetKey(var key: integer);
var
    symb: char;
begin
    symb := ReadKey;
    if symb = #0 then
    begin
        symb := ReadKey;
        key := -ord(symb);
    end 
    else if (ord(symb) = 208) or (ord(symb) = 209) then
    begin
        symb := ReadKey;
        key := ord(symb)
    end
    else begin
        key := ord(symb)
    end
end;

procedure InitListOfWords(var WordsList: ListOfWordsPtr);
begin
    WordsList.first := nil;
    WordsList.last := nil; 
end;

procedure AddWordInList(var list: ListOfWordsPtr; word: string);
var 
tmp: ListOfWordsElemPtr;
begin
    if list.first = nil then
    begin
         new(list.first);
         list.first^.word := word;
         list.first^.index := 0;
         list.first^.NextWordPtr := nil;
         list.last := List.first
    end
    else begin
        new(list.last^.NextWordPtr);
        tmp := list.last^.NextWordPtr;
        tmp^.index := list.last^.index + 1;
        tmp^.word := word; 
        tmp^.NextWordPtr := nil;
        list.last := tmp
    end
end;

procedure ShowHelpInfo(OldTextAttr: integer);
begin
    GotoXY(HelpInfoBarX, HelpInfoBarY);
    TextColor(white);
    write(ExitMsg + ' ');
    TextColor(red); 
    writeln('Esc');

    TextColor(white);
    write(ChangeTextMsg + ' ');
    TextColor(red); 
    write('Enter');
    TextAttr := OldTextAttr
end;

procedure PrintInputField(x, y: integer);
var
    i, j: integer;
begin
    GotoXY(x, y); 
    for i := 1 to InputFieldHeight do
    begin
        for j := 1 to InputFieldWidth do
        begin
            if (i = 1) or (i = InputFieldHeight)or 
              (j = 1) or (j = InputFieldWidth) 
            then
                write(InputFieldBorderSymb)
            else 
                write(' ')
        end;
        GotoXY(x, y + i) 
    end;
end;


procedure ShowErrorCountBar(errors, FieldX, FieldY: integer);
var
    x, y: integer;
begin
    x := FieldX - ErrorCountBarPaddingX;
    y := FieldY - ErrorCountBarPaddingY;
    GotoXY(x, y);
    write(ErrorCountBarMsg, errors);
end;

function GetErrorCountDigits(errors: integer): integer;
var
    count: integer;
begin
    count := 0;
    while errors <> 0 do
    begin
        errors := errors div 10;
        count := count + 1
    end;
    GetErrorCountDigits := count
end;

procedure HideOldErrorCount(errors, FieldX, FieldY: integer);
var
    x, y, count, i: integer;
begin
    x := FieldX - ErrorCountBarPaddingX + length(ErrorCountBarMsg); 
    y := FieldY - ErrorCountBarPaddingY;
    count := GetErrorCountDigits(errors);
    GotoXY(x, y);
    for i := 1 to count do
        write(' ')
end;

procedure ShowNewErrorCount(errors, FieldX,FieldY: integer); 
var
    x, y: integer;
begin
    x := FieldX - ErrorCountBarPaddingX + length(ErrorCountBarMsg); 
    y := FieldY - ErrorCountBarPaddingY;
    GotoXY(x, y);
    write(errors)
end;

function IsCharLatin(s: char): boolean;
begin
    if ((s >= 'a') and (s <= 'z')) or 
        ((s >= 'A') and (s <= 'Z')) then
    begin
        IsCharLatin := True
    end
    else
        IsCharLatin := False
end;

{Puts words from the file into the list}
procedure LoadWordsFromFile(var f: CharFile; var list: ListOfWordsPtr); 
var
    symb: char;
    word: string;
begin
    word := '';
    while not Eof(f) do 
    begin
        read(f, symb);
        if IsCharLatin(symb) then begin
            word := word + symb
        end
        else if (ord(symb) = SpaceCharCode) or 
               (ord(symb) = LineFeedCharCode) then
        begin
            if word <> '' then
            begin
                AddWordInList(list, word); 
                word := ''
            end 
        end 
    end
end;

function IsListEmpty(var list: ListOfWordsPtr): boolean;
begin
    IsListEmpty := (list.first = nil)
end;

function CanAppendWordToText(var text, word: string): boolean;
var
    TextLen, WordLen: integer;
begin
    TextLen := length(text);
    WordLen := length(word);
    if (TextLen + WordLen) <= (MaxTypingTextLen) then
        CanAppendWordToText := True
    else
        CanAppendWordToText := False
end;

{Makes line of random words from the list}
procedure MakeTypingText(var list: ListOfWordsPtr; var text: string);
var
    ListLength, ElemIndex, i: integer;
    tmp: ListOfWordsElemPtr;
    TextTmp, word: string;
begin
    ListLength := list.last^.index;
    TextTmp := '';
    word := '';
    while CanAppendWordToText(TextTmp, word) do
    begin
        if word <> '' then
            TextTmp := TextTmp + word + ' ';
        ElemIndex := random(ListLength);
        tmp := list.first;
        for i := 0 to ElemIndex do
        begin
            tmp := tmp^.NextWordPtr
        end;
        word := tmp^.word;
    end;
    {Delete last ' ' from the line}
    Delete(TextTmp, length(TextTmp), 1);
    text := TextTmp
end;

procedure PrintTypingText(x,y: integer; var text: string); 
begin
    GotoXY(x,y); 
    write(text);
    GotoXY(x, y)
end;

procedure DeleteOldTypingText(x, y, TextLen: integer);
var
    i: integer;
begin
    GotoXY(x, y);
    for i := 1 to TextLen do
    begin
        write(' ')
    end;
    GotoXY(x, y)
end;

procedure ColorizePressedSymb(symb: char; color: integer);
begin
    TextColor(color);
    write(symb);
end;


procedure ChangeText(x, y: integer; var list: ListOfWordsPtr; var text: string);
begin
    DeleteOldTypingText(x,y,length(text));
    MakeTypingText(list, text);
    PrintTypingText(x, y, text)
end;

procedure MoveCursorBack(var x, y, index: integer; var text:string); 
begin
    index := index - 1;
    GotoXY(x + index - 1, y);
    write(text[index]);
    GotoXY(x + index - 1, y)
end;

procedure CheckTerminalSize;
begin
    if (ScreenWidth < TerminalMinSizeWidth) or
      (ScreenHeight < TerminalMinSizeHeight) then
    begin
        write(TerminalSizeErrorMsg);
        halt(1)
    end
end;

var 
    {On which character in the text is the cursor} 
    CurrentCharIndex: integer;
    CenterOfScreenX, CenterOfScreenY: integer;
    {Field upper left corner coordinates} 
    StartFieldX, StartFieldY: integer;
    TypingLineStartX, TypingLineStartY: integer;
    TypingErrors: integer;
    OldTextAttr: integer;
    TypingTextLen: integer;
    f: CharFile;
    WordsList: ListOfWordsPtr;
    key: integer;
    TypingText: string;
begin
    CheckTerminalSize;
    if ParamCount < 1 then
    begin 
        writeln(NoParamErrorMsg);
        halt(1);
    end;
    filemode := 0;
    assign(f, ParamStr(1));
    reset(f);
    if IOResult <> 0 then
    begin
        writeln(OpenFileErrorMsg);
        halt(1)
    end;
    LoadWordsFromFile(f, WordsList);
    close(f);
    if IsListEmpty(WordsList) then
    begin
        writeln(EmptyListErrorMsg);
        halt(1)
    end;
    clrscr; 
    randomize;
    CenterOfScreenX := ScreenWidth div 2;
    CenterOfScreenY := ScreenHeight div 2;
    StartFieldX := CenterOfScreenX - (InputFieldWidth div 2);
    StartFieldY := CenterOfScreenY - (InputFieldHeight div 2);
    TypingLineStartX := StartFieldX + TypingTextPaddingX;
    TypingLineStartY := StartFieldY + TypingTextPaddingY;
    OldTextAttr := TextAttr;
    TypingErrors := 0;
    CurrentCharIndex := 1;
    PrintInputField(StartFieldX, StartFieldY);
    ShowHelpInfo(OldTextAttr);
    ShowErrorCountBar(TypingErrors, StartFieldX, StartFieldY);
    MakeTypingText(WordsList,TypingText);
    TypingTextLen := length(TypingText);
    PrintTypingText(TypingLineStartX, TypingLineStartY, TypingText);
    while True do
    begin
        if KeyPressed then
        begin
            GetKey(key);
            case key of
            EscapeCharCode:
                begin
                    break
                end;
            EnterCharCode:
                begin
                    TextAttr := OldTextAttr;
                    CurrentCharIndex := 1;
                    ChangeText(
                        TypingLineStartX,
                        TypingLineStartY,
                        WordsList,
                        TypingText
                        );
                    TypingTextLen := length(TypingText);
                    HideOldErrorCount(TypingErrors, StartFieldX, StartFieldY);
                    TypingErrors := 0; 
                    ShowNewErrorCount(TypingErrors,StartFieldX, StartFieldY);
                    GotoXY(TypingLineStartX, TypingLineStartY)
                end;
            BackSpaceCharCode:
                begin
                    if CurrentCharIndex <> 1 then
                    begin
                        TextAttr := OldTextAttr;
                        MoveCursorBack(
                            TypingLineStartX,
                            TypingLineStartY,
                            CurrentCharIndex,
                            TypingText
                            )
                    end
                end;
            else
                begin
                    if key = ord(TypingText[CurrentCharIndex]) then
                    begin
                        ColorizePressedSymb(
                            TypingText[CurrentCharIndex], 
                            LightGreen
                            )
                    end else 
                    begin
                        ColorizePressedSymb(TypingText[CurrentCharIndex], red);
                        TypingErrors := TypingErrors + 1;
                        ShowNewErrorCount(TypingErrors, StartFieldX, StartFieldY);
                    end;
                    GotoXY(
                        TypingLineStartX + CurrentCharIndex, 
                        TypingLineStartY
                        );
                    CurrentCharIndex := CurrentCharIndex + 1
                end;
            end;
            {User finished the text line} 
            if (CurrentCharIndex - 1) = TypingTextLen then
            begin
                write;
                Delay(TextEndDelayMs);
                TextAttr := OldTextAttr;
                CurrentCharIndex := 1;
                ChangeText(
                    TypingLineStartX,
                    TypingLineStartY,
                    WordsList,
                    TypingText
                    );
                TypingTextLen := length(TypingText);
                HideOldErrorCount(TypingErrors, StartFieldX, StartFieldY);
                TypingErrors := 0; 
                ShowNewErrorCount(TypingErrors,StartFieldX, StartFieldY);
                GotoXY(TypingLineStartX, TypingLineStartY)
            end
        end else
            Delay(NoKeyPressDelayMs)
    end;
    TextAttr := OldTextAttr;
    clrscr
end.


