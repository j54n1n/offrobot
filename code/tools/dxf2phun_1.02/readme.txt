//==============================================================================
//  dx2phun  (C)2013 Yuusui
//==============================================================================
CAD is useful when you make Phun/Algodoo objects.
So,I make this application.
It can convert Phun/Algodoo objects from dxf file.
Dxf file is supported many CAD application.

Phun/Algodoo is a 2D physics engine created by Emil Ernerfeldt.

//------------------------------------------------------------------------------
[Summary]
//------------------------------------------------------------------------------
This application convert circle or polygon of Phun/Algodoo objects from 
dxf file entities that CIRCLE , ARC and LINE.
Converted data is output clipboard and textbox as Thyme script. 
You can import objects by pasting thyme script onto screen.

//------------------------------------------------------------------------------
[Features]
//------------------------------------------------------------------------------
 * Input file is only dxf file.
 * This application can output multiple objects designed by CAD.
 * Relative objects position designed by CAD is maintained after converted into 
   Phun/Algodoo.
 * This application can convert POINT into hinge when polygon exist only one.
 * If convert process has failed, error point is shown by fixjoint.

//------------------------------------------------------------------------------
[Supported DXF command]
//------------------------------------------------------------------------------
 * CIRCLE : output circle
 * ARC    : output polygon (After an arc is converted into multiple line,this
            application converts the lines into polygon.)
 * LINE   : output polygon (This application converts continuous lines into polygon.)
 * POINT  : output hinge (It operates, when a polygon is one. When Polygons exist
            many,please use CIRCLE comand insted of POINT.After this application
            outputs circle, please add hinge on circle on Phun/Algodoo.)

//------------------------------------------------------------------------------
[Attention]
//------------------------------------------------------------------------------
Please draw polygon without exist isolated line or arc.
Please do not stack the line. if you needed, please do not branch a line.  
(Crossed line is OK. Circle can cross any element.)

//------------------------------------------------------------------------------
[Screen Description]
//------------------------------------------------------------------------------
FileName:Please Drop DXF File here

Data Epsilon: When this application converts continuous lines into polygon.
if exist gap between startpoint and endpoint, can treat as the same point 
by adjust the parameter.

Arc Interval:When arc is converted into multiple line,arc is divided into 
several lines. The interval of a line is specified with the parameter. For 
example, When the parameter is 5 degree, 90 degree arc is divided into 90/5=18 
lines.

Convert & Copy ClipBoard:After execute convert, this application outputs thyme 
code to textbox and clipboard.You can choose unit [mm] or [m] on cad drawing.
In addition, dxf file doesn't treat unit.

//------------------------------------------------------------------------------
[Attachment File]
//------------------------------------------------------------------------------
dxf2phun
„¥readme.txt               Readme file(This text)
„¥readme_jp.txt            Readme file(Japanese)
„¥license.txt              License document of this application(English)
„¥license_jp.txt           License document of this application(Japanse)
„¥dxf2phun.exe             Execute file
„ 
„¥language                 Language Setting File
„ „¥English.ini
„ „¤Japanese.ini
„ 
„¤sample                   Sample files of dxf
  „¥fan.dxf
  „¤Geneva.dxf

//------------------------------------------------------------------------------
[Howto install]
//------------------------------------------------------------------------------
Please expand at any place,and use this application.
It needs .NET Framework 4.0.

//------------------------------------------------------------------------------
[Howto uninstall]
//------------------------------------------------------------------------------
only delete folder. because this application dosen't use registry key.

//------------------------------------------------------------------------------
[Platform]
//------------------------------------------------------------------------------
Win32

//------------------------------------------------------------------------------
[License]
//------------------------------------------------------------------------------
Please read "license.txt" or "license_jp.txt".
The intention of the license is to ensure that the dxf2phun source code (the 
code that is compiled into the dxf2phun executable) remains free software by 
using the BSD license on the dxf2phun source code. dxf2phun is a code generator 
and the intention of the license is also to enable distribution of the output code 
under license terms of the user's choice/requirements. 


//------------------------------------------------------------------------------
[Operation Check]
//------------------------------------------------------------------------------
Algodoo v2.1.0 + Jw_cad 6.20a
Phun v5.28     + Jw_cad 6.20a


//------------------------------------------------------------------------------
[ChangeLog]
//------------------------------------------------------------------------------
1.02
   * Fix: Changed Label into Textbox at control of input file
   * New: Added support localization
   
1.01
   * New: Added support multi objects
   * New: Added support CIRCLE command
   * New: Added error visualize on Phun/Algodoo
   
1.00
   * New: Initial release

//------------------------------------------------------------------------------
[Contact Information]
//------------------------------------------------------------------------------
E-Mail : pchousuu[at mark]yahoo.co.jp
URL    : http://sourceforge.jp/projects/dxf2phun/simple/