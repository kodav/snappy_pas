unit SnappyCl;

// C port https://github.com/andikleen/snappy-c

interface

uses
  Windows, Classes, SysUtils, Math;

type
  TSnappyDecompressor = Class
    class procedure Decompress(InputA: TArray<Byte>; var OutputA: TArray<Byte>); overload;
    class procedure Decompress(InputA: TArray<Byte>; Offset, Length: integer; var OutputA: TArray<Byte>); overload;
  end;

  TSnappyCompressor = Class
    class procedure Compress(uncompressed: TArray<Byte>; var compressed: TArray<Byte>); overload;
    class procedure Compress(uncompressed: TArray<Byte>; Offset, Length_: integer; var compressed: TArray<Byte>); overload;
  end;

implementation

uses
  AnsiStrings;

function IfThen(cond: boolean; tvalue, fvalue: integer): integer; inline;
begin
  if cond then
    result := tvalue
  else
    result := fvalue;
end;

// ================================ TSnappyDecompressor ====================================
class procedure TSnappyDecompressor.Decompress(InputA: TArray<Byte>; var OutputA: TArray<Byte>);
begin
  Decompress(InputA, 0, Length(InputA), OutputA);
end;

class procedure TSnappyDecompressor.Decompress(InputA: TArray<Byte>; Offset, Length: integer; var OutputA: TArray<Byte>);
  function incPP(var AVal : integer; dec_v : integer = 1): integer;
  begin
    result := AVal;
    inc(AVal, dec_v);
  end;

var
  i, l, o, c, targetIndex, SourceIndex, targetLength: integer;
begin
  SourceIndex := Offset;
  targetIndex := 0;
  targetLength := 0;
  i := 0;

  repeat
    targetLength := targetLength + (InputA[SourceIndex] and $7F) shl (incPP(i) * 7);
  until ((InputA[incPP(SourceIndex)] and $80) <> $80);

  SetLength(OutputA, targetLength);

  while (SourceIndex < Offset + Length) do
  begin
    if (targetIndex >= targetLength) then
      raise Exception.Create('Superfluous input data encountered on offset ' + IntToStr(SourceIndex));

    case (InputA[SourceIndex] and 3) of
      0:
        begin
          l := (InputA[incPP(SourceIndex)] shr 2) and $3F;
          case l of
            60:
              begin
                l :=        InputA[incPP(SourceIndex)] and $FF;
                inc(l);
              end;
            61:
              begin
                l :=        InputA[incPP(SourceIndex)] and $FF;
                l := l or ((InputA[incPP(SourceIndex)] and $FF) shl 8);
                inc(l);
              end;
            62:
              begin
                l :=        InputA[incPP(SourceIndex)] and $FF;
                l := l or ((InputA[incPP(SourceIndex)] and $FF) shl 8);
                l := l or ((InputA[incPP(SourceIndex)] and $FF) shl 16);
                inc(l);
              end;
            63:
              begin
                l :=        InputA[incPP(SourceIndex)] and $FF;
                l := l or ((InputA[incPP(SourceIndex)] and $FF) shl 8);
                l := l or ((InputA[incPP(SourceIndex)] and $FF) shl 16);
                l := l or ((InputA[incPP(SourceIndex)] and $FF) shl 24);
                inc(l);
              end;
            else
              inc(l);
          end;
          // System.arraycopy(in, sourceIndex, outBuffer, targetIndex, l);
          Move(InputA[SourceIndex], OutputA[targetIndex], l);
          inc(SourceIndex, l);
          inc(targetIndex, l);
        end;
      1:
        begin
          l := 4 + ((InputA[SourceIndex] shr 2) and 7);
          o :=      (InputA[incPP(SourceIndex)] and $E0) shl 3;
          o := o or (InputA[incPP(SourceIndex)] and $FF);
          if (l < o) then
          begin
            Move(OutputA[targetIndex - o], OutputA[targetIndex], l);
            inc(targetIndex, l);
          end
          else
          begin
            if (o = 1) then
            begin
              FillChar(OutputA[targetIndex], l, OutputA[targetIndex-1]);
              inc(targetIndex, l);
            end
            else
            begin
              while (l > 0) do
              begin
                c := IfThen(l > o, o, l);
                // System.arraycopy(outBuffer, targetIndex - o, outBuffer, targetIndex, c);
                Move(OutputA[targetIndex - o], OutputA[targetIndex], c);
                inc(targetIndex, c);
                dec(l, c);
              end;
            end;
          end;
        end;
      2:
        begin
          l := ((InputA[incPP(SourceIndex)] shr 2) and $3F) + 1;
          o := InputA[incPP(SourceIndex)] and $FF;
          o := o or ((InputA[incPP(SourceIndex)] and $FF) shl 8);
          if (l < o) then
          begin
            Move(OutputA[abs(targetIndex - o)], OutputA[targetIndex], l);
            inc(targetIndex, l);
          end
          else
          begin
            while (l > 0) do
            begin
              c := IfThen(l > o, o, l);
              // System.arraycopy(outBuffer, targetIndex - o, outBuffer, targetIndex, c);
              Move(OutputA[targetIndex - o], OutputA[targetIndex], c);
              inc(targetIndex, c);
              dec(l, c);
            end;
          end;
        end;
      3:
        begin
          l := ((InputA[incPP(SourceIndex)] shr 2) and $3F) + 1;
          o := InputA[incPP(SourceIndex)] and $FF;
          o := o or ((InputA[incPP(SourceIndex)] and $FF) shl 8);
          o := o or ((InputA[incPP(SourceIndex)] and $FF) shl 16);
          o := o or ((InputA[incPP(SourceIndex)] and $FF) shl 24);
          if (l < o) then
          begin
            Move(OutputA[targetIndex - o], OutputA[targetIndex], l);
            inc(targetIndex, l);
          end
          else
          begin
            if (o = 1) then
            begin
              FillChar(OutputA[targetIndex], l, OutputA[targetIndex-1]);
              inc(targetIndex, l);
            end
            else
            begin
              while (l > 0) do
              begin
                c := IfThen(l > o, o, l);
                // System.arraycopy(outBuffer, targetIndex - o, outBuffer, targetIndex, c);
                Move(OutputA[targetIndex - o], OutputA[targetIndex], c);
                inc(targetIndex, c);
                dec(l, c);
              end;
            end;
          end;
        end;
    end;
  end;
end;

// ================================ TSnappyCompressor ====================================
function toInt(data: TArray<Byte>; Offset: integer): integer;
begin
  result := (((data[Offset] and $FF) shl 24) or ((data[Offset + 1] and $FF) shl 16) or ((data[Offset + 2] and $FF) shl 8) or (data[Offset + 3] and $FF)) and $7FFFFFFF;
end;

class procedure TSnappyCompressor.Compress(uncompressed: TArray<Byte>; var compressed: TArray<Byte>);
begin
  Compress(uncompressed, 0, Length(uncompressed), compressed);
end;

class procedure TSnappyCompressor.Compress(uncompressed: TArray<Byte>; Offset, Length_: integer; var compressed: TArray<Byte>);
type
  Hit = record
    Offset: integer;
    Length: integer;
  end;

  function incPP(var AVal : integer; dec_v : integer = 1): integer;
  begin
    result := AVal;
    inc(AVal, dec_v);
  end;

  function search(source: TArray<Byte>; index, _length: integer; ilhm_: TArray<integer>): Hit;
  var
    l, _len, i, fp, Offset, o, io: integer;
  begin
    if (index + 4 >= _length) then
    begin
      // We won't search for backward references if there are less than
      // four bytes left to encode, since no relevant compression can be
      // achieved and the map used to store possible back references uses
      // a four byte key.
      result.Offset := -1;
      result.Length := -1;
      exit;
    end;

    if (index > 0) and
      (source[index] = source[index - 1]) and
      (source[index] = source[index + 1]) and
      (source[index] = source[index + 2]) and
      (source[index] = source[index + 3]) then
    begin

      // at least five consecutive bytes, so we do
      // run-length-encoding of the last four
      // (three bytes are required for the encoding,
      // so less than four bytes cannot be compressed)

      _len := 0;
      i := index;
      while (_len < 64) and (i < _length) and (source[index] = source[i]) do
      begin
        inc(i);
        inc(_len);
      end;
      result.Offset := 1;
      result.Length := _len;
      exit;
    end;

    fp := ilhm_[toInt(source, index) mod Length(ilhm_)];
    if (fp < 0) then
    begin
      result.Offset := -1;
      result.Length := -1;
      exit;
    end;

    Offset := index - fp;
    if (Offset < 4) then
    begin
      result.Offset := -1;
      result.Length := -1;
      exit;
    end;

    l := 0;
    o := fp;
    io := index;
    while (io < _length) and (source[o] = source[io]) and (o < index) and (l < 64) do
    begin
      inc(l);
      inc(o);
      inc(io);
    end;

    if l >= 4 then
    begin
      result.Offset := Offset;
      result.Length := l;
    end
    else
    begin
      result.Offset := -1;
      result.Length := -1;
    end;
  end;

var
  ilhm: TArray<integer>;
  targetIndex, lasthit, l, i, _len: integer;
  h: Hit;
  target : TArray<Byte>;
  b : Byte;
begin
  SetLength(compressed, trunc(Length_ * 6 / 5));

  target := compressed;
  targetIndex := 0;
  lasthit := Offset;

  l := Length_;
  while (l > 0) do
  begin
    if (l >= 128) then
      target[incPP(targetIndex)] := Byte($80 or (l and $7F))
    else
      target[incPP(targetIndex)] := Byte(l);
    l := l shr 7;
  end;

  SetLength(ilhm, trunc(Length_ / 5));
  for i := 0 to Length(ilhm) - 1 do
    ilhm[i] := -1;

  i := Offset;
  while (i + 4 < Length_) and (i < Offset + 4) do
  begin
    ilhm[toInt(uncompressed, i) mod Length(ilhm)] := i;
    inc(i);
  end;

  i := Offset + 4;
  while (i < Offset + Length_) do
  begin
    h := search(uncompressed, i, Length_, ilhm);
    if (i + 4 < Offset + Length_) then
      ilhm[toInt(uncompressed, i) mod Length(ilhm)] := i;
    if (h.Offset <> -1) then
    begin
      if (lasthit < i) then
      begin
        _len := i - lasthit - 1;
        if (_len < 60) then
        begin
          target[incPP(targetIndex)] := Byte(_len shl 2);
        end
        else if (_len < $100) then
        begin
          target[incPP(targetIndex)] := Byte(60 shl 2);
          target[incPP(targetIndex)] := Byte(_len);
        end
        else if (_len < $10000) then
        begin
          target[incPP(targetIndex)] := Byte(61 shl 2);
          target[incPP(targetIndex)] := Byte(_len);
          target[incPP(targetIndex)] := Byte(_len shr 8);
        end
        else if (_len < $1000000) then
        begin
          target[incPP(targetIndex)] := Byte(62 shl 2);
          target[incPP(targetIndex)] := Byte(_len);
          target[incPP(targetIndex)] := Byte(_len shr 8);
          target[incPP(targetIndex)] := Byte(_len shr 16);
        end
        else
        begin
          target[incPP(targetIndex)] := Byte(63 shl 2);
          target[incPP(targetIndex)] := Byte(_len);
          target[incPP(targetIndex)] := Byte(_len shr 8);
          target[incPP(targetIndex)] := Byte(_len shr 16);
          target[incPP(targetIndex)] := Byte(_len shr 24);
        end;
        // System.arraycopy(uncompressed, lasthit, target, targetIndex, i-lasthit);
        Move(uncompressed[lasthit], target[targetIndex], i - lasthit);
        incPP(targetIndex, i - lasthit);
        lasthit := i;
      end;
      if (h.Length <= 11) and (h.Offset < 2048) then
      begin
        target[targetIndex] := 1;
        target[targetIndex] := target[targetIndex] or ((h.Length - 4) shl 2);
        b := target[targetIndex] or (h.Offset shr 3) and $E0;;
        target[incPP(targetIndex)] := b;
        target[incPP(targetIndex)] := Byte(h.Offset and $FF);
      end
      else if (h.Offset < 65536) then
      begin
        target[targetIndex] := 2;
        b := target[targetIndex] or ((h.Length - 1) shl 2);
        target[incPP(targetIndex)] := b;
        target[incPP(targetIndex)] := Byte(h.Offset);
        target[incPP(targetIndex)] := Byte(h.Offset shr 8);
      end
      else
      begin
        target[targetIndex] := 3;
        b := target[targetIndex] or ((h.Length - 1) shl 2);
        target[incPP(targetIndex)] := b;
        target[incPP(targetIndex)] := Byte(h.Offset);
        target[incPP(targetIndex)] := Byte(h.Offset shr 8);
        target[incPP(targetIndex)] := Byte(h.Offset shr 16);
        target[incPP(targetIndex)] := Byte(h.Offset shr 24);
      end;
      while i < lasthit do
      begin
        if (i + 4 < Length(uncompressed)) then
          ilhm[toInt(uncompressed, i) mod Length(ilhm)] := i;
        inc(i);
      end;

      lasthit := i + h.Length;

      while (i < lasthit - 1) do
      begin
        if (i + 4 < Length(uncompressed)) then
          ilhm[toInt(uncompressed, i) mod Length(ilhm)] := i;
        inc(i);
      end;
    end
    else
    begin
      if (i + 4 < Length_) then
        ilhm[toInt(uncompressed, i) mod Length(ilhm)] := i;
    end;
    inc(i);
  end;

  if (lasthit < Offset + Length_) then
  begin
    _len := (Offset + Length_) - lasthit - 1;
    if (_len < 60) then
    begin
      target[incPP(targetIndex)] := Byte(_len shl 2);
    end
    else if (_len < $100) then
    begin
      target[incPP(targetIndex)] := Byte(60 shl 2);
      target[incPP(targetIndex)] := Byte(_len);
    end
    else if (_len < $10000) then
    begin
      target[incPP(targetIndex)] := Byte(61 shl 2);
      target[incPP(targetIndex)] := Byte(_len);
      target[incPP(targetIndex)] := Byte(_len shr 8);
    end
    else if (_len < $1000000) then
    begin
      target[incPP(targetIndex)] := Byte(62 shl 2);
      target[incPP(targetIndex)] := Byte(_len);
      target[incPP(targetIndex)] := Byte(_len shr 8);
      target[incPP(targetIndex)] := Byte(_len shr 16);
    end
    else
    begin
      target[incPP(targetIndex)] := Byte(63 shl 2);
      target[incPP(targetIndex)] := Byte(_len);
      target[incPP(targetIndex)] := Byte(_len shr 8);
      target[incPP(targetIndex)] := Byte(_len shr 16);
      target[incPP(targetIndex)] := Byte(_len shr 24);
    end;
    // System.arraycopy(uncompressed, lasthit, target, targetIndex, Len - lasthit);
    Move(uncompressed[lasthit], target[targetIndex], Length_ - lasthit);
    IncPP(targetIndex, Length_ - lasthit);
  end;

  SetLength(compressed, targetIndex);
end;

end.
