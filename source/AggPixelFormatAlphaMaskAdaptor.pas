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
unit AggPixelFormatAlphaMaskAdaptor;

interface

{$INCLUDE AggCompiler.inc}


uses
  AggBasics,
  AggColor32,
  AggRenderingBuffer,
  AggPixelFormat,
  AggAlphaMaskUnpacked8;

const
  CSpanExtraTail = 256;

type
  TAggPixelFormatProcessorAlphaMaskAdaptor = class(TAggPixelFormatProcessor)
  private
    FPixelFormats: TAggPixelFormatProcessor;
    FMask: TAggCustomAlphaMask;

    FSpan: PInt8u;
    FMaxLength: Cardinal;
  public
    constructor Create(PixelFormat: TAggPixelFormatProcessor; Mask: TAggCustomAlphaMask);
    destructor Destroy; override;

    procedure ReallocSpan(length: Cardinal);

    procedure IniTAggSpan(length: Cardinal); overload;
    procedure IniTAggSpan(length: Cardinal; Covers: PInt8u); overload;
  end;

implementation

procedure CopyHorizontalLineAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; C: PAggColor);
begin
  This.ReallocSpan(length);
  This.FMask.FillHSpan(X, Y, This.FSpan, length);
  This.FPixelFormats.BlendSolidHSpan(This.FPixelFormats, X, Y, length, C,
    This.FSpan);
end;

procedure BlendHorizontalLineAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; C: PAggColor; Cover: Int8u);
begin
  This.IniTAggSpan(length);
  This.FMask.CombineHSpan(X, Y, This.FSpan, length);
  This.FPixelFormats.BlendSolidHSpan(This.FPixelFormats, X, Y, length, C,
    This.FSpan);
end;

procedure BlendVerticalLineAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; C: PAggColor; Cover: Int8u);
begin
  This.IniTAggSpan(length);
  This.FMask.CombineVSpan(X, Y, This.FSpan, length);
  This.FPixelFormats.BlendSolidVSpan(This.FPixelFormats, X, Y, length, C,
    This.FSpan);
end;

procedure BlendSolidHSpanAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; C: PAggColor; Covers: PInt8u);
begin
  This.IniTAggSpan(length, Covers);
  This.FMask.CombineHSpan(X, Y, This.FSpan, length);
  This.FPixelFormats.BlendSolidHSpan(This.FPixelFormats, X, Y, length, C,
    This.FSpan);
end;

procedure BlendSolidVSpanAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; C: PAggColor; Covers: PInt8u);
begin
  This.IniTAggSpan(length, Covers);
  This.FMask.CombineVSpan(X, Y, This.FSpan, length);
  This.FPixelFormats.BlendSolidVSpan(This.FPixelFormats, X, Y, length, C,
    This.FSpan);
end;

procedure BlendColorHSpanAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; COLORS: PAggColor; Covers: PInt8u;
  Cover: Int8u);
begin
  if Covers <> nil then
    begin
      This.IniTAggSpan(length, Covers);
      This.FMask.CombineHSpan(X, Y, This.FSpan, length);
    end
  else
    begin
      This.ReallocSpan(length);
      This.FMask.FillHSpan(X, Y, This.FSpan, length);
    end;

  This.FPixelFormats.BlendColorHSpan(This.FPixelFormats, X, Y, length, COLORS,
    This.FSpan, Cover);
end;

procedure BlendColorVSpanAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; length: Cardinal; COLORS: PAggColor; Covers: PInt8u;
  Cover: Int8u);
begin
  if Covers <> nil then
    begin
      This.IniTAggSpan(length, Covers);
      This.FMask.CombineVSpan(X, Y, This.FSpan, length);
    end
  else
    begin
      This.ReallocSpan(length);
      This.FMask.FillVSpan(X, Y, This.FSpan, length);
    end;

  This.FPixelFormats.BlendColorVSpan(This.FPixelFormats, X, Y, length, COLORS,
    This.FSpan, Cover);
end;

procedure BlendPixelAdaptor(This: TAggPixelFormatProcessorAlphaMaskAdaptor;
  X, Y: Integer; C: Pointer; Cover: Int8u);
begin
  This.FPixelFormats.BlendPixel(This.FPixelFormats, X, Y, C,
    This.FMask.CombinePixel(X, Y, Cover));
end;

{ TAggPixelFormatProcessorAlphaMaskAdaptor }

constructor TAggPixelFormatProcessorAlphaMaskAdaptor.Create(
  PixelFormat: TAggPixelFormatProcessor; Mask: TAggCustomAlphaMask);
begin
  inherited Create(PixelFormat.RenderingBuffer);

  FPixelFormats := PixelFormat;
  FMask := Mask;

  FSpan := nil;
  FMaxLength := 0;

  CopyHorizontalLine := @CopyHorizontalLineAdaptor;
  BlendHorizontalLine := @BlendHorizontalLineAdaptor;
  BlendVerticalLine := @BlendVerticalLineAdaptor;

  BlendSolidHSpan := @BlendSolidHSpanAdaptor;
  BlendSolidVSpan := @BlendSolidVSpanAdaptor;
  BlendColorHSpan := @BlendColorHSpanAdaptor;
  BlendColorVSpan := @BlendColorVSpanAdaptor;

  BlendPixel := @BlendPixelAdaptor;
end;

destructor TAggPixelFormatProcessorAlphaMaskAdaptor.Destroy;
begin
  if Assigned(FSpan) then
      AggFreeMem(Pointer(FSpan), FMaxLength * SizeOf(Int8u));
  inherited;
end;

procedure TAggPixelFormatProcessorAlphaMaskAdaptor.ReallocSpan;
begin
  if length > FMaxLength then
    begin
      AggFreeMem(Pointer(FSpan), FMaxLength * SizeOf(Int8u));

      FMaxLength := length + CSpanExtraTail;

      AggGetMem(Pointer(FSpan), FMaxLength * SizeOf(Int8u));
    end;
end;

procedure TAggPixelFormatProcessorAlphaMaskAdaptor.IniTAggSpan(length: Cardinal);
begin
  ReallocSpan(length);

  FillChar(FSpan^, length * SizeOf(Int8u), CAggCoverFull);
end;

procedure TAggPixelFormatProcessorAlphaMaskAdaptor.IniTAggSpan(length: Cardinal;
  Covers: PInt8u);
begin
  ReallocSpan(length);

  Move(Covers^, FSpan^, length * SizeOf(Int8u));
end;

end. 
 
