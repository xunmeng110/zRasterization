{ ****************************************************************************** }
{ * memory Rasterization with AGG support                                      * }
{ * by QQ 600585@qq.com                                                        * }
{ ****************************************************************************** }
{ * https://github.com/PassByYou888/CoreCipher                                 * }
{ * https://github.com/PassByYou888/ZServer4D                                  * }
{ * https://github.com/PassByYou888/zExpression                                * }
{ * https://github.com/PassByYou888/zTranslate                                 * }
{ * https://github.com/PassByYou888/zSound                                     * }
{ * https://github.com/PassByYou888/zAnalysis                                  * }
{ * https://github.com/PassByYou888/zGameWare                                  * }
{ * https://github.com/PassByYou888/zRasterization                             * }
{ ****************************************************************************** }

(*
  ////////////////////////////////////////////////////////////////////////////////
  //                                                                            //
  //  Anti-Grain Geometry (modernized Pascal fork, aka 'AggPasMod')             //
  //    Maintained by Christian-W. Budde (Christian@pcjv.de)                    //
  //    Copyright (c) 2012-2017                                                 //
  //                                                                            //
  //  Based on:                                                                 //
  //    Pascal port by Milan Marusinec alias Milano (milan@marusinec.sk)        //
  //    Copyright (c) 2005-2006, see http://www.aggpas.org                      //
  //                                                                            //
  //  Original License:                                                         //
  //    Anti-Grain Geometry - Version 2.4 (Public License)                      //
  //    Copyright (C) 2002-2005 Maxim Shemanarev (http://www.antigrain.com)     //
  //    Contact: McSeem@antigrain.com / McSeemAgg@yahoo.com                     //
  //                                                                            //
  //  Permission to copy, use, modify, sell and distribute this software        //
  //  is granted provided this copyright notice appears in all copies.          //
  //  This software is provided "as is" without express or implied              //
  //  warranty, and with no claim as to its suitability for any purpose.        //
  //                                                                            //
  ////////////////////////////////////////////////////////////////////////////////
*)
unit AggRendererScanLine;

interface

{$INCLUDE AggCompiler.inc}


uses
  AggBasics,
  AggRendererBase,
  AggColor32,
  AggScanline,
  AggScanlinePacked,
  AggScanlineBin,
  AggSpanGenerator,
  AggSpanAllocator,
  AggRasterizerScanLine,
  AggRasterizerCompoundAA;

type
  TAggCustomRendererScanLine = class // class(TAggRasterizerScanLine)
  public
    procedure Prepare(u: Cardinal); virtual; abstract;
    procedure Render(SL: TAggCustomScanLine); virtual; abstract;
  end;

  TAggRendererScanLineAA = class(TAggCustomRendererScanLine)
  private
    FRen: TAggRendererBase;
    FSpanGen: TAggSpanGenerator;
  public
    constructor Create; overload;
    constructor Create(Ren: TAggRendererBase; SpanGen: TAggSpanGenerator); overload;

    procedure Attach(Ren: TAggRendererBase; SpanGen: TAggSpanGenerator);

    procedure Prepare(u: Cardinal); override;
    procedure Render(SL: TAggCustomScanLine); override;
  end;

  TAggCustomRendererScanLineSolid = class(TAggCustomRendererScanLine)
  public
    procedure SetColor(C: PAggColor); overload; virtual; abstract;
    procedure SetColor(C: TAggRgba8); overload; virtual; abstract;
  end;

  TAggRendererScanLineAASolid = class(TAggCustomRendererScanLineSolid)
  private
    FRen: TAggRendererBase;
    FColor: TAggColor;
  public
    constructor Create(Ren: TAggRendererBase);

    procedure SetColor(C: PAggColor); override;
    procedure SetColor(C: TAggRgba8); override;
    procedure Prepare(u: Cardinal); override;
    procedure Render(SL: TAggCustomScanLine); override;
  end;

  TAggRendererScanLineBinSolid = class(TAggCustomRendererScanLineSolid)
  private
    FRen: TAggRendererBase;
    FColor: TAggColor;
  public
    constructor Create(Ren: TAggRendererBase);

    procedure SetColor(C: PAggColor); override;
    procedure SetColor(C: TAggRgba8); override;
    procedure Prepare(u: Cardinal); override;
    procedure Render(SL: TAggCustomScanLine); override;
  end;

  TAggCustomStyleHandler = class
  public
    function IsSolid(Style: Cardinal): Boolean; virtual; abstract;
    function GetColor(Style: Cardinal): PAggColor; virtual; abstract;

    procedure GenerateSpan(Span: PAggColor; X, Y: Integer; Len, Style: Cardinal); virtual; abstract;
  end;

procedure RenderScanLineAASolid(SL: TAggCustomScanLine; Ren: TAggRendererBase; COLOR: PAggColor);

procedure RenderScanLinesAASolid(Ras: TAggRasterizerScanLine; SL: TAggCustomScanLine; Ren: TAggRendererBase; COLOR: PAggColor);

procedure RenderScanLinesCompound(Ras: TAggRasterizerCompoundAA; ScanLineAA, SlBin: TAggCustomScanLine; Ren: TAggRendererBase; Alloc: TAggSpanAllocator; StyleHandler: TAggCustomStyleHandler);

procedure RenderScanLinesCompoundLayered(Ras: TAggRasterizerCompoundAA; ScanLineAA: TAggCustomScanLine; Ren: TAggRendererBase; Alloc: TAggSpanAllocator; StyleHandler: TAggCustomStyleHandler);

implementation


{ TAggRendererScanLineAA }

constructor TAggRendererScanLineAA.Create;
begin
  FRen := nil;
  FSpanGen := nil;
end;

constructor TAggRendererScanLineAA.Create(Ren: TAggRendererBase;
  SpanGen: TAggSpanGenerator);
begin
  Assert(Ren is TAggRendererBase);
  FRen := Ren;
  FSpanGen := SpanGen;
end;

procedure TAggRendererScanLineAA.Attach(Ren: TAggRendererBase;
  SpanGen: TAggSpanGenerator);
begin
  Assert(Ren is TAggRendererBase);
  FRen := Ren;
  FSpanGen := SpanGen;
end;

procedure TAggRendererScanLineAA.Prepare(u: Cardinal);
begin
  FSpanGen.Prepare(u);
end;

procedure TAggRendererScanLineAA.Render(SL: TAggCustomScanLine);
var
  Y, XMin, XMax, X, Len: Integer;

  NumSpans: Cardinal;
  // SS: Cardinal;

  // Span  : PAggSpanRecord;
  Span: TAggCustomSpan;
  Solid: Boolean;
  Covers: PInt8u;
begin
  Y := SL.Y;

  FRen.FirstClipBox;

  repeat
    XMin := FRen.XMin;
    XMax := FRen.XMax;

    if (Y >= FRen.YMin) and (Y <= FRen.YMax) then
      begin
        NumSpans := SL.NumSpans;

        Span := SL.GetBegin;
        // Ss := Sl.SizeOfSpan;

        repeat
          X := Span.X;
          Len := Span.Len;

          Solid := False;
          Covers := Span.Covers;

          if Len < 0 then
            begin
              Solid := True;
              Len := -Len;
            end;

          if X < XMin then
            begin
              Dec(Len, XMin - X);

              if not Solid then
                  Inc(PtrComp(Covers), XMin - X);

              X := XMin;
            end;

          if Len > 0 then
            begin
              if X + Len > XMax then
                  Len := XMax - X + 1;

              if Len > 0 then
                if Solid then
                    FRen.BlendColorHSpanNoClip(X, Y, Len,
                    FSpanGen.Generate(X, Y, Len), nil, Covers^)
                else
                    FRen.BlendColorHSpanNoClip(X, Y, Len,
                    FSpanGen.Generate(X, Y, Len), Covers, Covers^);
            end;

          Dec(NumSpans);

          if NumSpans = 0 then
              Break;

          // Inc(PtrComp(Span), Ss);
          Span.IncOperator;
        until False;

        Span.Free;
      end;

  until not FRen.NextClipBox;
end;

{ TAggRendererScanLineAASolid }

constructor TAggRendererScanLineAASolid.Create(Ren: TAggRendererBase);
begin
  Assert(Ren is TAggRendererBase);
  FRen := Ren;
end;

procedure TAggRendererScanLineAASolid.SetColor(C: PAggColor);
begin
  Assert(Assigned(C));
  FColor := C^;
end;

procedure TAggRendererScanLineAASolid.SetColor(C: TAggRgba8);
begin
  FColor.FromRgba8(C);
end;

procedure TAggRendererScanLineAASolid.Prepare(u: Cardinal);
begin
end;

procedure TAggRendererScanLineAASolid.Render(SL: TAggCustomScanLine);
var
  X, Y: Integer;
  // Ss: Cardinal;
  // SpanRecord : PAggSpanRecord;
  NumSpans: Cardinal;
  Span: TAggCustomSpan;
begin
  Y := SL.Y;

  NumSpans := SL.NumSpans;

  // SpanRecord := nil;
  // Span := nil;

  // if Sl.IsPlainSpan then
  // begin
  // SpanRecord := Sl.GetBegin;
  // Ss := Sl.SizeOfSpan;
  // end
  // else
  // Span := Sl.GetBegin;
  Span := SL.GetBegin;

  { if SpanRecord <> nil then
    repeat
    X := SpanRecord.X;

    if SpanRecord.Len > 0 then
    FRen.BlendSolidHSpan(X, Y, Cardinal(SpanRecord.Len), @FColor,
    SpanRecord.Covers)
    else
    FRen.BlendHorizontalLine(X, Y, Cardinal(X - SpanRecord.Len - 1), @FColor,
    SpanRecord.Covers^);

    Dec(NumSpans);

    if NumSpans = 0 then
    Break;

    Inc(PtrComp(SpanRecord), Ss);
    until False
    else
    begin }
  repeat
    X := Span.X;

    if Span.Len > 0 then
        FRen.BlendSolidHSpan(X, Y, Cardinal(Span.Len), @FColor,
        Span.Covers)
    else
        FRen.BlendHorizontalLine(X, Y, Cardinal(X - Span.Len - 1), @FColor,
        Span.Covers^);

    Dec(NumSpans);

    if NumSpans = 0 then
        Break;

    Span.IncOperator;
  until False;

  Span.Free;
  { end; }
end;

{ TAggRendererScanLineBinSolid }

constructor TAggRendererScanLineBinSolid.Create(Ren: TAggRendererBase);
begin
  Assert(Ren is TAggRendererBase);
  FRen := Ren;
end;

procedure TAggRendererScanLineBinSolid.SetColor(C: PAggColor);
begin
  FColor := C^;
end;

procedure TAggRendererScanLineBinSolid.SetColor(C: TAggRgba8);
begin
  FColor.FromRgba8(C);
end;

procedure TAggRendererScanLineBinSolid.Prepare(u: Cardinal);
begin
end;

procedure TAggRendererScanLineBinSolid.Render(SL: TAggCustomScanLine);
var
  // SpanPl: PAggSpanRecord;
  // Ss: Cardinal;
  Span: TAggCustomSpan;
  NumSpans: Cardinal;
begin
  NumSpans := SL.NumSpans;

  { SpanPl := nil;
    Span := nil;

    if Sl.IsPlainSpan then
    begin
    SpanPl := Sl.GetBegin;
    Ss := Sl.SizeOfSpan;
    end
    else
    Span := Sl.GetBegin; }
  Span := SL.GetBegin;

  { if SpanPl <> nil then
    repeat
    if SpanPl.Len < 0 then
    FRen.BlendHorizontalLine(SpanPl.X, Sl.Y, SpanPl.X - 1 - SpanPl.Len,
    @FColor, CAggCoverFull)
    else
    FRen.BlendHorizontalLine(SpanPl.X, Sl.Y, SpanPl.X - 1 + SpanPl.Len,
    @FColor, CAggCoverFull);

    Dec(NumSpans);

    if NumSpans = 0 then
    Break;

    Inc(PtrComp(SpanPl), Ss);
    until False
    else }
  repeat
    if Span.Len < 0 then
        FRen.BlendHorizontalLine(Span.X, SL.Y, Span.X - 1 - Span.Len,
        @FColor, CAggCoverFull)
    else
        FRen.BlendHorizontalLine(Span.X, SL.Y, Span.X - 1 + Span.Len,
        @FColor, CAggCoverFull);

    Dec(NumSpans);

    if NumSpans = 0 then
        Break;

    Span.IncOperator;
  until False;

  Span.Free;
end;

procedure RenderScanLineAASolid(SL: TAggCustomScanLine; Ren: TAggRendererBase;
  COLOR: PAggColor);
var
  Y, X: Integer;
  NumSpans: Cardinal;
  // Ss: Cardinal;
  // Span: PAggSpanRecord;
  Span: TAggCustomSpan;
begin
  Assert(Ren is TAggRendererBase);

  Y := SL.Y;
  NumSpans := SL.NumSpans;
  Span := SL.GetBegin;
  // Ss := Sl.SizeOfSpan;

  repeat
    X := Span.X;

    if Span.Len > 0 then
        Ren.BlendSolidHSpan(X, Y, Cardinal(Span.Len), COLOR, Span.Covers)
    else
        Ren.BlendHorizontalLine(X, Y, Cardinal(X - Span.Len - 1), COLOR, Span.Covers^);

    Dec(NumSpans);

    if NumSpans = 0 then
        Break;

    // Inc(PtrComp(Span), Ss);
    Span.IncOperator;
  until False;

  Span.Free;
end;

procedure RenderScanLinesAASolid(Ras: TAggRasterizerScanLine;
  SL: TAggCustomScanLine; Ren: TAggRendererBase; COLOR: PAggColor);
var
  Y, X: Integer;
  NumSpans: Cardinal;
  // Ss: Cardinal;
  // Span: PAggSpanRecord;
  Span: TAggCustomSpan;
begin
  Assert(Ren is TAggRendererBase);

  if Ras.RewindScanLines then
    begin
      SL.Reset(Ras.MinimumX, Ras.MaximumX);

      while Ras.SweepScanLine(SL) do
        begin
          Y := SL.Y;
          NumSpans := SL.NumSpans;
          // Ss := Sl.SizeOfSpan;
          Span := SL.GetBegin;

          repeat
            X := Span.X;

            if Span.Len > 0 then
                Ren.BlendSolidHSpan(X, Y, Cardinal(Span.Len), COLOR, Span.Covers)
            else
                Ren.BlendHorizontalLine(X, Y, Cardinal(X - Span.Len - 1), COLOR,
                Span.Covers^);

            Dec(NumSpans);

            if NumSpans = 0 then
                Break;

            // Inc(PtrComp(Span), Ss);
            Span.IncOperator;
          until False;

          Span.Free;
        end;
    end;
end;

procedure RenderScanLinesCompound(Ras: TAggRasterizerCompoundAA;
  ScanLineAA, SlBin: TAggCustomScanLine; Ren: TAggRendererBase;
  Alloc: TAggSpanAllocator; StyleHandler: TAggCustomStyleHandler);
var
  MinX, Len: Integer;
  NumSpans, NumStyles, Style, i: Cardinal;
  // SsAntiAlias, SsBin: Cardinal;
  ColorSpan, MixBuffer, COLORS, ClrSpan: PAggColor;
  C: TAggColor;
  Solid: Boolean;
  // SpanAA: PAggSpanRecord;
  // SpanBin: PAggSpanBin;
  SpanAA: TAggCustomSpan;
  SpanBin: TAggCustomSpan;
  Covers: PInt8u;
begin
  Assert(Ren is TAggRendererBase);

  if Ras.RewindScanLines then
    begin
      MinX := Ras.MinimumX;
      Len := Ras.MaximumX - MinX + 2;

      ScanLineAA.Reset(MinX, Ras.MaximumX);
      SlBin.Reset(MinX, Ras.MaximumX);

      ColorSpan := Alloc.Allocate(Len * 2);
      MixBuffer := PAggColor(PtrComp(ColorSpan) + Len * SizeOf(TAggColor));

      NumStyles := Ras.SweepStyles;

      while NumStyles > 0 do
        begin
          if NumStyles = 1 then
            // Optimization for a single style. Happens often
            if Ras.SweepScanLine(ScanLineAA, 0) then
              begin
                Style := Ras.Style(0);

                if StyleHandler.IsSolid(Style) then
                  // Just solid fill
                    RenderScanLineAASolid(ScanLineAA, Ren, StyleHandler.GetColor(Style))
                else
                  begin
                    // Arbitrary Span generator
                    SpanAA := ScanLineAA.GetBegin;
                    // SsAntiAlias := ScanLineAA.SizeOfSpan;
                    NumSpans := ScanLineAA.NumSpans;

                    repeat
                      Len := SpanAA.Len;

                      StyleHandler.GenerateSpan(ColorSpan, SpanAA.X, ScanLineAA.Y, Len, Style);
                      Ren.BlendColorHSpan(SpanAA.X, ScanLineAA.Y, SpanAA.Len, ColorSpan,
                        SpanAA.Covers);

                      Dec(NumSpans);

                      if NumSpans = 0 then
                          Break;

                      // Inc(PtrComp(SpanAA), SsAntiAlias);
                      SpanAA.IncOperator;
                    until False;

                    SpanAA.Free;
                  end;
              end
            else
          else // if NumStyles = 1 ... else
            if Ras.SweepScanLine(SlBin, -1) then
              begin
                // Clear the Spans of the MixBuffer
                SpanBin := SlBin.GetBegin;
                // SsBin := SlBin.SizeOfSpan;
                NumSpans := SlBin.NumSpans;

                repeat
                  FillChar(PAggColor(PtrComp(MixBuffer) + (SpanBin.X - MinX) *
                    SizeOf(TAggColor))^, SpanBin.Len * SizeOf(TAggColor), 0);

                  Dec(NumSpans);

                  if NumSpans = 0 then
                      Break;

                  // Inc(PtrComp(SpanBin), SsBin);
                  SpanBin.IncOperator;
                until False;

                SpanBin.Free;

                i := 0;

                while i < NumStyles do
                  begin
                    Style := Ras.Style(i);
                    Solid := StyleHandler.IsSolid(Style);

                    if Ras.SweepScanLine(ScanLineAA, i) then
                      begin
                        SpanAA := ScanLineAA.GetBegin;
                        // SsAntiAlias := ScanLineAA.SizeOfSpan;
                        NumSpans := ScanLineAA.NumSpans;

                        if Solid then
                          // Just solid fill
                          repeat
                            C := StyleHandler.GetColor(Style)^;
                            Len := SpanAA.Len;

                            COLORS := PAggColor(PtrComp(MixBuffer) + (SpanAA.X - MinX)
                              * SizeOf(TAggColor));
                            Covers := SpanAA.Covers;

                            repeat
                              if Covers^ = CAggCoverFull then
                                  COLORS^ := C
                              else
                                  COLORS.Add(@C, Covers^);

                              Inc(PtrComp(COLORS), SizeOf(TAggColor));
                              Inc(PtrComp(Covers), SizeOf(Int8u));
                              Dec(Len);

                            until Len = 0;

                            Dec(NumSpans);

                            if NumSpans = 0 then
                                Break;

                            // Inc(PtrComp(SpanAA), SsAntiAlias);
                            SpanAA.IncOperator;

                          until False

                        else
                          // Arbitrary Span generator
                          repeat
                            Len := SpanAA.Len;
                            COLORS := PAggColor(PtrComp(MixBuffer) + (SpanAA.X - MinX)
                              * SizeOf(TAggColor));
                            ClrSpan := ColorSpan;

                            StyleHandler.GenerateSpan(ClrSpan, SpanAA.X, ScanLineAA.Y,
                              Len, Style);

                            Covers := SpanAA.Covers;

                            repeat
                              if Covers^ = CAggCoverFull then
                                  COLORS^ := ClrSpan^
                              else
                                  COLORS.Add(ClrSpan, Covers^);

                              Inc(PtrComp(ClrSpan), SizeOf(TAggColor));
                              Inc(PtrComp(COLORS), SizeOf(TAggColor));
                              Inc(PtrComp(Covers), SizeOf(Int8u));
                              Dec(Len);

                            until Len = 0;

                            Dec(NumSpans);

                            if NumSpans = 0 then
                                Break;

                            // Inc(PtrComp(SpanAA), SsAntiAlias);
                            SpanAA.IncOperator;

                          until False;

                        SpanAA.Free;
                      end;

                    Inc(i);
                  end;

                // Emit the blended result as a color hSpan
                SpanBin := SlBin.GetBegin;
                // SsBin := SlBin.SizeOfSpan;
                NumSpans := SlBin.NumSpans;

                repeat
                  Ren.BlendColorHSpan(SpanBin.X, SlBin.Y, SpanBin.Len,
                    PAggColor(PtrComp(MixBuffer) + (SpanBin.X - MinX) *
                    SizeOf(TAggColor)), 0, CAggCoverFull);

                  Dec(NumSpans);

                  if NumSpans = 0 then
                      Break;

                  // Inc(PtrComp(SpanBin), SsBin);
                  SpanBin.IncOperator;
                until False;

                SpanBin.Free;
              end; // if ras.SweepScanLine(SlBin ,-1 )

          NumStyles := Ras.SweepStyles;
        end; // while NumStyles > 0
    end;     // if ras.RewindScanLines
end;

procedure RenderScanLinesCompoundLayered(Ras: TAggRasterizerCompoundAA;
  ScanLineAA: TAggCustomScanLine; Ren: TAggRendererBase; Alloc: TAggSpanAllocator;
  StyleHandler: TAggCustomStyleHandler);
var
  MinX, Len, ScanLineStart, Sl_y: Integer;
  NumSpans, NumStyles, Style, ScanLineLen, i, Cover: Cardinal;
  // SsAntiAlias: Cardinal;
  ColorSpan, MixBuffer, COLORS, ClrSpan: PAggColor;
  Solid: Boolean;
  C: TAggColor;
  CoverBuffer, SourceCovers, DestCovers: PCover;
  // SpanAA: PAggSpanRecord;
  SpanAA: TAggCustomSpan;
begin
  Assert(Ren is TAggRendererBase);

  if Ras.RewindScanLines then
    begin
      MinX := Ras.MinimumX;
      Len := Ras.MaximumX - MinX + 2;

      ScanLineAA.Reset(MinX, Ras.MaximumX);

      ColorSpan := Alloc.Allocate(Len * 2);
      MixBuffer := PAggColor(PtrComp(ColorSpan) + Len * SizeOf(TAggColor));
      CoverBuffer := Ras.AllocateCoverBuffer(Len);

      NumStyles := Ras.SweepStyles;

      while NumStyles > 0 do
        begin
          if NumStyles = 1 then
            // Optimization for a single style. Happens often
            if Ras.SweepScanLine(ScanLineAA, 0) then
              begin
                Style := Ras.Style(0);

                if StyleHandler.IsSolid(Style) then
                  // Just solid fill
                    RenderScanLineAASolid(ScanLineAA, Ren, StyleHandler.GetColor(Style))

                else
                  begin
                    // Arbitrary Span generator
                    SpanAA := ScanLineAA.GetBegin;
                    NumSpans := ScanLineAA.NumSpans;
                    // SsAntiAlias := ScanLineAA.SizeOfSpan;

                    repeat
                      Len := SpanAA.Len;

                      StyleHandler.GenerateSpan(ColorSpan, SpanAA.X, ScanLineAA.Y, Len, Style);
                      Ren.BlendColorHSpan(SpanAA.X, ScanLineAA.Y, SpanAA.Len, ColorSpan,
                        SpanAA.Covers);

                      Dec(NumSpans);

                      if NumSpans = 0 then
                          Break;

                      // Inc(PtrComp(SpanAA), SsAntiAlias);
                      SpanAA.IncOperator;

                    until False;

                    SpanAA.Free;
                  end;

              end
            else
          else
            begin
              ScanLineStart := Ras.ScanLineStart;
              ScanLineLen := Ras.ScanLineLength;

              if ScanLineLen <> 0 then
                begin
                  FillChar(PAggColor(PtrComp(MixBuffer) + (ScanLineStart - MinX) *
                    SizeOf(TAggColor))^, ScanLineLen * SizeOf(TAggColor), 0);

                  FillChar(PCover(PtrComp(CoverBuffer) + (ScanLineStart - MinX) *
                    SizeOf(TCover))^, ScanLineLen * SizeOf(TCover), 0);

                  Sl_y := $7FFFFFFF;

                  i := 0;

                  while i < NumStyles do
                    begin
                      Style := Ras.Style(i);
                      Solid := StyleHandler.IsSolid(Style);

                      if Ras.SweepScanLine(ScanLineAA, i) then
                        begin
                          SpanAA := ScanLineAA.GetBegin;
                          NumSpans := ScanLineAA.NumSpans;
                          Sl_y := ScanLineAA.Y;
                          // SsAntiAlias := ScanLineAA.SizeOfSpan;

                          if Solid then
                            // Just solid fill
                            repeat
                              C := StyleHandler.GetColor(Style)^;

                              Len := SpanAA.Len;
                              COLORS := PAggColor(PtrComp(MixBuffer) + (SpanAA.X - MinX)
                                * SizeOf(TAggColor));

                              SourceCovers := PCover(SpanAA.Covers);
                              DestCovers :=
                                PCover(PtrComp(CoverBuffer) + (SpanAA.X - MinX) *
                                SizeOf(TCover));

                              repeat
                                Cover := SourceCovers^;

                                if DestCovers^ + Cover > CAggCoverFull then
                                    Cover := CAggCoverFull - DestCovers^;

                                if Cover <> 0 then
                                  begin
                                    COLORS.Add(@C, Cover);

                                    DestCovers^ := DestCovers^ + Cover;
                                  end;

                                Inc(PtrComp(COLORS), SizeOf(TAggColor));
                                Inc(PtrComp(SourceCovers), SizeOf(TCover));
                                Inc(PtrComp(DestCovers), SizeOf(TCover));
                                Dec(Len);

                              until Len = 0;

                              Dec(NumSpans);

                              if NumSpans = 0 then
                                  Break;

                              // Inc(PtrComp(SpanAA), SsAntiAlias);
                              SpanAA.IncOperator;

                            until False
                          else
                            // Arbitrary Span generator
                            repeat
                              Len := SpanAA.Len;
                              COLORS := PAggColor(PtrComp(MixBuffer) + (SpanAA.X - MinX)
                                * SizeOf(TAggColor));
                              ClrSpan := ColorSpan;

                              StyleHandler.GenerateSpan(ClrSpan, SpanAA.X, ScanLineAA.Y, Len, Style);

                              SourceCovers := PCover(SpanAA.Covers);
                              DestCovers :=
                                PCover(PtrComp(CoverBuffer) + (SpanAA.X - MinX) *
                                SizeOf(TCover));

                              repeat
                                Cover := SourceCovers^;

                                if DestCovers^ + Cover > CAggCoverFull then
                                    Cover := CAggCoverFull - DestCovers^;

                                if Cover <> 0 then
                                  begin
                                    COLORS.Add(ClrSpan, Cover);

                                    DestCovers^ := DestCovers^ + Cover;
                                  end;

                                Inc(PtrComp(ClrSpan), SizeOf(TAggColor));
                                Inc(PtrComp(COLORS), SizeOf(TAggColor));
                                Inc(PtrComp(SourceCovers), SizeOf(TCover));
                                Inc(PtrComp(DestCovers), SizeOf(TCover));
                                Dec(Len);

                              until Len = 0;

                              Dec(NumSpans);

                              if NumSpans = 0 then
                                  Break;

                              // Inc(PtrComp(SpanAA), SsAntiAlias);
                              SpanAA.IncOperator;

                            until False;

                          SpanAA.Free;
                        end;

                      Inc(i);
                    end;

                  Ren.BlendColorHSpan(ScanLineStart, Sl_y, ScanLineLen,
                    PAggColor(PtrComp(MixBuffer) + (ScanLineStart - MinX) * SizeOf(TAggColor)
                    ), 0, CAggCoverFull);

                end; // if ScanLineLen <> 0

            end; // if NumStyles = 1 ... else

          NumStyles := Ras.SweepStyles;

        end; // while NumStyles > 0

    end; // if ras.RewindScanLines
end;

end. 
 
