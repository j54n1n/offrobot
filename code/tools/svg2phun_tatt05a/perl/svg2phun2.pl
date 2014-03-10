#! /usr/bin/perl -w
#
# last updated : 2008/10/26
#
# Usage:
#   svg2phun2.pl file.svg
# 
# This script converts data from SVG format to Phun format.
#
# Objects in the same layer is converted into those of the same
# body-ID in SVG.  Similarly, objects in the same group is converted
# into those of the same body-ID.  When layer and group are co-exist,
# the layer wins in the grouping of objects.
# 
# About SVG2Phun2: tatt61880
#      http://www.sakai.zaq.ne.jp/dugyj708/svg2phun_tatt/index.html
#
# About SVG2Phun: t0m0tomo
#      http://www.nicovideo.jp/watch/sm2589929
#      http://youtube.com/watch?v=PPhOBfFEjHA
#      http://www.geocities.jp/int_real_float/svg2phun/
#
use SVG::Parser;
use SVG::Parser::Expat;

#use SVG::Parser qw(SAX=XML::LibXML::Parser::SAX Expat SAX);
#use Data::Dumper;
use Math::Bezier::Convert;
use List::Util qw(max min);
use strict;

### Default parameters of Phun objects ###
## polygon, circle
my $DENSITY = 2.0;
my $FRICTION = 0.5;
my $RESTITUTION = 0.5;
my $ANGLE = 0.0;
my $FILLCOLOR = "#FFFFFF";
## spring
my $SPRINGCOLOR = "#FFFFFF";
my $DAMPINGFACTOR = 0.1;
my $SIZE = 0.5;
my $STRENGTHFACTOR = 0.05;
## hinge
my $HINGECOLOR = "#FFFFFF";
my $CCW = 'false';
my $CONTROLLER = '';
my $MOTOR = 'false';
my $MOTORSPEED = 1.570796370506287;
my $MOTORTORQUE = 100;

## for $geomID__
my $geomID_svg2phun2 = -1;

### Default parameters for conversion ###
my $SCALE = 1/72.;
my $YOFFSET = 0;
my $XOFFSET = 0;
my $PI = 3.141592;
my $PerPoint = 2;      # Phun-unit per point
my $IDOFFSET = 3;      # id of the first object
my $ZDEPTH = 0;
my $DIGIT = '[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?'; # regexp for digit (int, float)

# ---------------------------------------
# Default parameters for accuracy of path
# ---------------------------------------
$Math::Bezier::Convert::APPROX_QUADRATIC_TOLERANCE = 1; # modeule-default = 1 
$Math::Bezier::Convert::APPROX_LINE_TOLERANCE = 0.5;   # modeule-default = 1 
$Math::Bezier::Convert::CTRL_PT_TOLERANCE = 1.5;      # module-default = 3 (must be >=1.5)

### Read SVG file ###
die "Usage: $0 file.svg\n" unless @ARGV;
my $Infile = $ARGV[0];
die "Usage: $0 file.svg\n" unless ($Infile =~ /\.svg$/i);
die "$ARGV[0] is not found.\n" unless (-e $ARGV[0]);

&readConf;

### read configuration file ###
sub readConf{
   my $conffile = 'config.txt';
   my $dir = $0;
   my $APPROX_LINE_TOLERANCE;
   local $/=undef;
   $dir =~ s#[^/\\]+$##;
   $conffile = $dir . $conffile;
   open(F, "$conffile") or return; #die $!, "$conffile\n";
   print STDERR "Reading configuration file $conffile\n";
   my $conftxt = <F>;
   close F;
   $conftxt = $1 if ($conftxt =~ m{<svg2phun2>([\d\D]*)</svg2phun2>}g);
   eval($conftxt);
   $Math::Bezier::Convert::APPROX_LINE_TOLERANCE = $APPROX_LINE_TOLERANCE
   if defined $APPROX_LINE_TOLERANCE;
}

my $Xml;
my $Phun_config = '';   # thyme script expect "Scene.add__{};" and "Keys.bind{};" command.
my $Phun_addGroup = '';
my $Phun_addWidget = '';
my $Phun_addWater = ''; # Scene.addWater { vecs = [[x,y],[x,y], ..., [x,y]]};
{
   local $/=undef;
   $Xml=<>;
   $Phun_addGroup .= "Scene.addGroup {" . $1 . "};\n" 
            while ($Xml =~ /<!-- PHUN ADDGROUP ([\d\D]*?) -->/g); # {}の中身を取り出す。
   $Phun_addWidget .= "Scene.addWidget {" . $1 . "};\n" 
            while ($Xml =~ /<!-- PHUN ADDWIDGET ([\d\D]*?) -->/g); # {}の中身を取り出す。
            
   my @lines = split /\n/, $Xml;
   $Xml = "";
   foreach my $line ( @lines ) {
      $ZDEPTH++;
      $Phun_config .= "$1\n" if($line =~ /^<!-- PHUN THYME (.*)-->$/g);
      $line =~ s/id="/id="zDepth:$ZDEPTH;/g;
      $line =~ s/(<g id=")zDepth:[^;]*;(body:.*">)/$1$2/g;
      $Xml .= "$line\n";
   }
   
}

### Parse SVG ###
my $Svg;
{
   my $parser=new SVG::Parser(-debug => 0); # change -debug => 1 if you want to use debug method
   $Svg=$parser->parse($Xml);
}
#print Dumper($Svg);

### Convert data from SVG format to Phun format ###
my @Phun;
my %RevHash;
{
   my $robjs = $Svg->{-document}{-childs};
   my $nestLevel = 0;
   my $groupIdMax = 1;      # max of group ID in bottom level of SVG
   my $group;
   # for Inkscape. Inkscape make a <g> tag for only one layer.
   {
      my $seen = 0;
      my $nlayer;
      foreach ( 0 .. $#$robjs ) {
         if (exists $robjs->[$_]{-name} && $robjs->[$_]{-name} eq 'g' && 
               exists $robjs->[$_]{'inkscape:groupmode'} && $robjs->[$_]{'inkscape:groupmode'} eq 'layer') {
            $seen++;
            $nlayer = $_;
         }
      }
      $robjs = $robjs->[$nlayer]{-childs} if ( $seen == 1 );
   }
   # search bottom level groups for groupIdMax
   {
      foreach my $obj (@$robjs) {
         if ( $obj->{-name} eq 'g'  && exists $obj->{id} && $obj->{id} =~ /body:(\d+)/) {
            $groupIdMax = $1 if ( $1 > $groupIdMax );
         }
      }
   }
   
   &reformInkscapeTags( $robjs );
   &search_obj( $robjs );
   &reformParameter();
   &mkRevhash();
   &search_tool( $robjs );
   
   sub search_obj { #obj = addPolygon, addCircle, addBox, addPlane.
      my $robjs = $_[0];
      foreach ( 0 .. $#$robjs ) {
         my $obj = $robjs->[$_];
         $group = &getGroupID($obj, \$groupIdMax) if ( $nestLevel == 0 );
         if ( $obj->{-name} eq 'g' ) {
            $nestLevel++;
            &search_obj( $obj->{-childs} );
            $nestLevel--;
         } else {
            push @Phun, {body => $group };
            &eachObj ($obj);
         }
      }
   }
   
   sub search_tool { #tool = addSpring, addHinge, addPen. <- Those tool requires the geomID of the objects to which is attached.
      my $robjs = $_[0];
      foreach (0 .. $#$robjs) {
         my $obj = $robjs->[$_];
         if ( $obj->{-name} eq 'g' ) {
            &search_tool( $obj->{-childs} );
         } else {
            push @Phun, { name => $obj->{-name}};
            &eachTool ($obj);
         }
      }
   }
}

#print Dumper(\@Phun);

### --- Output file --- ###
{
   my $outfile = $Infile;
   $outfile =~ s/(\(\d+\))?\.svg$//i;
   unless ( -f "$outfile.phn" ) {
      $outfile = "$outfile.phn";
   } else {
      my $n=1;
      $n++ while ( -f "$outfile($n).phn" );
      $outfile = "$outfile($n).phn";
   }
   
   print STDERR "Outputing data to $outfile\n";
   open ( F, ">$outfile") || die $!, " $outfile\n";
   my $Oldfh = select (STDOUT);
   select F;
   print "// Phun scene created by svg2phun2\n";
   print $Phun_config;
   
   foreach my $id ( 0 ... $#Phun ) {
      if ( $Phun[$id]{type} eq "addCircle" ) {
         &printPhunCircle($id);
      } elsif ( $Phun[$id]{type} eq "addBox" ) {
         &printPhunBox($id);
      } elsif ( $Phun[$id]{type} eq "addPolygon" ) {
         &printPhunPolygon($id);
      } elsif ( $Phun[$id]{type} eq "addPlane" ) {
         &printPhunPlane($id);
      } elsif ( $Phun[$id]{type} eq "addSpring" ) {
         &printPhunSpring($id);
      } elsif ( $Phun[$id]{type} eq "addHinge" ) {
         &printPhunHinge($id);
      } elsif ( $Phun[$id]{type} eq "addFixjoint" ) {
         &printPhunFixjoint($id);
      } elsif ( $Phun[$id]{type} eq "addPen" ) {
         &printPhunPen($id);
      } else {
         print STDERR "Object type $Phun[$id]{type} is not supported.\n";
      }
   }
   print $Phun_addGroup;
   print $Phun_addWidget;
   
   if ($Phun_addWater){
      $Phun_addWater = substr($Phun_addWater, 2); 
      print 'Scene.addWater { vecs = ['.  $Phun_addWater . ']};';
   }
   select $Oldfh;
   close F;
}

exit;

# -----------------------------------------------------------------------------------

# Convert each object (Phun-plygon adn Phun-circle)
# INPUT:
#   SVG data
sub eachObj {
   my $obj = $_[0];
   if ( $obj->{-name} eq 'path' ) {
      &svg2phun_Path($obj);
   } elsif ( $obj->{-name} eq 'polygon' ) {
      &svg2phun_Polygon($obj);
   } elsif ( $obj->{-name} eq 'rect' ) {
      &svg2phun_Rect($obj);
   } elsif ( $obj->{-name} eq 'circle' ) {
      &svg2phun_Circle($obj);
   } elsif ( $obj->{-name} eq 'ellipse' ) {
      &svg2phun_Ellipse($obj);
   } elsif ( &isPlaneOrSpring($obj) eq 'addPlane' ) {
      &svg2phun_Plane($obj);
   } elsif ( $obj->{-name} eq 'polyline' ) {
      print STDERR "** Skipping object: ", $obj->{-name}, " because of open path", "\n";
      $Phun[$#Phun]{type} = "addPolyline";
   } else {
      pop @Phun;
   }
}

# Convert each tool (Spring and Hinge)
# INPUT:
#   SVG data
sub eachTool {
   my $obj = $_[0];
   if ( &isPlaneOrSpring eq 'addSpring' ) { # addSpring
      &svg2phun_Spring($obj);
   } elsif ( $obj->{-name} eq 'circle' ) { # addHinge or addPen
      (exists $obj->{'stroke-dasharray'} && $obj->{'stroke-dasharray'} ne 'none') ? &svg2phun_Pen($obj) : &svg2phun_Hinge($obj);
   } elsif ( $obj->{-name} eq 'polygon' ) { # addFixjoint
      &svg2phun_Fixjoint($obj);
   } elsif ( $obj->{-name} eq 'path' ) { # addFixJoint
      $obj->{d} =~ s/\n/ /;
      $obj->{d} =~ s/\r/ /;
      $obj->{d} =~ s/ *$//;
      my ( @objlist ) =  split(/z/,$obj->{d});
      if($#objlist == 0) {
         $obj->{points} = $objlist[0];
         &svg2phun_Fixjoint($obj);
      }
   }else {
      pop @Phun;
   }
}


# parse SVG id tags, which includ physical parameters for phun
# INPUT:
#   svgobj .... SVG object
# OUTPUT:
#   phunobj ... phun object
sub parseSvgId {
   my ($svgobj, $phunobj) = @_;
   $phunobj->{geomID__} = $geomID_svg2phun2--;
   return unless ( exists $svgobj->{id} );
   $svgobj->{id} =~ s/_x3B_/;/g;
   $svgobj->{id} =~ s/_x23_/#/g;
   foreach my $elem ( split( /;/, $svgobj->{id} ) ) {
      my ($key, $val) = split(/:/, $elem);
      
      if ( $key =~ /^(angle|density|restitution|dampingFactor|length|strengthFactor|motorSpeed|controllerAcc|zDepth)$/ ) {
         ($val)= ($val =~ /^($DIGIT)/);
      }
      elsif ($key =~ /^(motorTorque|friction|distanceLimit|impulseLimit)$/ ) {
         ($val)= ($val =~ /^($DIGIT|\+inf)/);
      }
      elsif ( $key =~ /^(id|body|group|geomID|entityID|collideSet|geom0|geom1)$/) {
         ($val)= ($val =~ /^(\d+|-\d+)/);
      } 
      elsif ( $key =~ /^(ccw|motor|tracked|collideWater|autoBrake|heteroCollide|controllerInvertX|controllerInvertY|controllerReverseXY)$/ ) {
         ($val)= ($val =~ /^(true|false)/);
      }
      elsif ($key =~ /^(buttonDestroy|buttonMirror|buttonBack|buttonBrake|buttonForward)$/) {
         ($val)= ($val =~ /^([^;]*)/);
      }
      elsif ($key =~ /^(geom0pos|geom1pos)$/ ) {
         ($val)= ($val =~ /^(\[$DIGIT,\s*$DIGIT\])/);
      }
      elsif ($key =~ /^(forceController)$/) {
         ($val =~ s/^(keys,([A-Za-z0-9]+),([A-Za-z0-9]+),([A-Za-z0-9]+),([A-Za-z0-9]+))/keys $2 $3 $4 $5/);
      }
      
      $phunobj->{$key} = $val unless ($key eq 'body'); # body is previously defined
   }
   
   return unless ( exists $svgobj->{style} );
   $svgobj->{style} =~ s/_x3B_/;/g;
   $svgobj->{style} =~ s/_x23_/#/g;
   foreach my $elem ( split( /;/, $svgobj->{style} ) ) {
      my ($key, $val) = split(/:/, $elem);
      
      if ( $key =~ /^(stroke\-opacity)$/ ) {
         ($val)= ($val =~ /^($DIGIT)/);
      }
      $phunobj->{$key} = $val;
   }
}

# Convert Path from SVG to Phun format.
# INPUT:
#   $obj ... object of path
sub svg2phun_Path {
   my $obj = $_[0];
   my ( @x, @y, @color );
   $obj->{d} =~ s/\n/ /;
   $obj->{d} =~ s/\r/ /;
   $obj->{d} =~ s/ *$//;
   my ( @objlist ) =  split(/z/,$obj->{d});
   foreach ( 0 .. $#objlist ) { # loop for compound path
      if ( $_ != 0 ) {            # copy objects
         my %rec = % {$Phun[$#Phun]};
         push @Phun, { %rec }; 
      }
      if ( exists $obj->{filter} && $obj->{filter} eq 'fixjoint' ) { # This circle is HINGE or Pen
         pop @Phun;      # delete this object.
         return;
      }
      &extractXY_from_SVG_path($objlist[$_], \@x, \@y);
      &transform($obj, \@x, \@y);
      &transformParentGroup($obj, \@x, \@y);
      $Phun[$#Phun]{x} = [ @x ];
      $Phun[$#Phun]{y} = [ @y ];
      $Phun[$#Phun]{type} = "addPolygon";
      
      &fillcolor( $obj, \@color );
      $Phun[$#Phun]{color} = \@color;
      
      &parseSvgId($obj, $Phun[$#Phun]);
      
      $Phun[$#Phun]{boundingbox} = &boundingBox( $Phun[$#Phun] );
      my ( $posx, $posy );
      &baricenter(\@x, \@y, \$posx, \$posy);
      $Phun[$#Phun]{posx} = $posx;
      $Phun[$#Phun]{posy} = $posy;
   }
}

# Convert Polygon from SVG to Phun format.
# INPUT:
#   $obj ... object of polygon
sub svg2phun_Polygon {
   my $obj = $_[0];
   my ( @x, @y, @color );
   &extractXY_from_SVG_polygon($obj->{points}, \@x, \@y);
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   if ( exists $obj->{filter} && $obj->{filter} eq 'fixjoint' ) { # This circle is HINGE or Pen
      pop @Phun;      # delete this object.
      return;
   }
   $Phun[$#Phun]{x} = \@x;
   $Phun[$#Phun]{y} = \@y;
   $Phun[$#Phun]{type} = "addPolygon";
   
   &fillcolor( $obj, \@color );
   $Phun[$#Phun]{color} = \@color;
   
   &parseSvgId($obj, $Phun[$#Phun]);
   $Phun[$#Phun]{boundingbox} = &boundingBox( $Phun[$#Phun] );
   my ( $posx, $posy );
   &baricenter(\@x, \@y, \$posx, \$posy);
   $Phun[$#Phun]{posx} = $posx;
   $Phun[$#Phun]{posy} = $posy;
}

# Convert Rect from SVG to Phun format.
# INPUT:
#   $obj ... object of rectangle
sub svg2phun_Rect {
   my $obj = $_[0];
   my ( @x, @y, @color );
   @x = (
      $obj->{x}, $obj->{x} + $obj->{width}, $obj->{x} + $obj->{width}, $obj->{x}
      );
   @y = (
      $obj->{y}, $obj->{y}, $obj->{y} + $obj->{height}, $obj->{y} + $obj->{height}
      );
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   $Phun[$#Phun]{x} = \@x;
   $Phun[$#Phun]{y} = \@y;
   if (exists $obj->{transform} && $obj->{transform} =~ /matrix/) {
      my ($a, $b, $c, $d, $e, $f) = &split_digit($obj->{transform});
      if ($a == $d && $b == -$c){
         $Phun[$#Phun]{type} = "addBox";
      } else {
         $Phun[$#Phun]{type} = "addPolygon";
      }
   } else {
      $Phun[$#Phun]{type} = "addBox";
   }
   &fillcolor( $obj, \@color );
   $Phun[$#Phun]{color} = \@color;
   &parseSvgId($obj, $Phun[$#Phun]);
   $Phun[$#Phun]{boundingbox} = &boundingBox( $Phun[$#Phun] );
   my ( $posx, $posy );
   &baricenter(\@x, \@y, \$posx, \$posy);
   $Phun[$#Phun]{posx} = $posx;
   $Phun[$#Phun]{posy} = $posy;
}

# Convert Circle from SVG to Phun format.
# INPUT:
#   $obj ... object of circle
sub svg2phun_Circle {
   my $obj = $_[0];
   my @color;

   &fillcolor( $obj, \@color );
   unless ( @color ) {      # This circle is HINGE or Pen
      pop @Phun;      # delete this object.
      return;
   }
   $Phun[$#Phun]{color} = \@color;

   my $cx = $obj->{cx};
   my $cy = $obj->{cy};
   my $r = $obj->{r};
   &transformCircle($obj, \$cx, \$cy, \$r);
   &transformParentGroupCircle($obj,  \$cx, \$cy, \$r);
   $Phun[$#Phun]{radius} = $r;
   $Phun[$#Phun]{posx} =  $cx;
   $Phun[$#Phun]{posy} =  $cy;
   $Phun[$#Phun]{type} = "addCircle";
   &parseSvgId($obj, $Phun[$#Phun]);
   $Phun[$#Phun]{boundingbox} = &boundingBox( $Phun[$#Phun] );
   
   $Phun[$#Phun]{filter} = $obj->{filter} if exists $obj->{filter}; #for Scene.addWater
}

# Convert Ellipse from SVG to Phun format.
# INPUT:
#   $obj ... object of circle
sub svg2phun_Ellipse {
   my $obj = $_[0];
   my @color;
   my ( @x, @y );
   my $NSEG = 30;
   my $rx = $obj->{rx};
   my $ry = $obj->{ry};
   my $cx = $obj->{cx}, 
   my $cy = $obj->{cy};
   foreach ( 0 .. $NSEG - 1){
      push(@x, $cx + $rx * cos( 2 * $PI * $_ / $NSEG ) );
      push(@y, $cy + $ry * sin( 2 * $PI * $_ / $NSEG ) );
   }
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   $Phun[$#Phun]{x} = \@x;
   $Phun[$#Phun]{y} = \@y;
   $Phun[$#Phun]{type} = "addPolygon";
   &fillcolor( $obj, \@color );
   $Phun[$#Phun]{color} = \@color;
   &parseSvgId($obj, $Phun[$#Phun]);
   my ( $posx, $posy );
   &baricenter(\@x, \@y, \$posx, \$posy);
   $Phun[$#Phun]{boundingbox} = &boundingBox( $Phun[$#Phun] );
   $Phun[$#Phun]{posx} = $posx;
   $Phun[$#Phun]{posy} = $posy;
}

# Convert Ellipse from SVG to Phun format.
# INPUT:
#   $obj ... object of circle
sub svg2phun_Plane {
   my $obj = $_[0];
   my $phun = $Phun[$#Phun];
   &parseSvgId($obj, $phun);
   my @x = ( $obj->{x1}, $obj->{x2} );
   my @y = ( $obj->{y1}, $obj->{y2} );
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   my ( $x0, $x1 ) = @x;
   my ( $y0, $y1 ) = @y;
   # transverse vector
   my ( $tx, $ty ) = ( $x1 - $x0, $y1 - $y0 );
   $phun->{angle} = atan2( $tx , $ty );
   $phun->{posx} = ( $x0 + $x1 )/2;
   $phun->{posy} = ( $y0 + $y1 )/2;

   my @color;
   &fillcolor( $obj, \@color ); # for collide option
   $phun->{collideSet} -= 32;
   &strokecolor( $obj, \@color ); # for stroke color
   $phun->{color} = \@color;
   $phun->{type} = "addPlane";
}

# get bounding box of object for a given phun-object.
# INPUT:
#   a phun object
# RETURN:
#   a bounding box in arrary including coordinates of upper-left and lower-right points
sub boundingBox {
   my $obj = $_[0];
   my ( $xmin, $ymin, $xmax, $ymax );
   if ( $obj->{type} eq 'addPolygon' || $obj->{type} eq 'addBox'  ) {
      $xmax = max @{$obj->{x}};
      $xmin = min @{$obj->{x}};
      $ymax = max @{$obj->{y}};
      $ymin = min @{$obj->{y}};
   } elsif ( $obj->{type} eq 'addCircle' ) {
      $xmax = $obj->{posx} + $obj->{radius};
      $xmin = $obj->{posx} - $obj->{radius};
      $ymax = $obj->{posy} + $obj->{radius};
      $ymin = $obj->{posy} - $obj->{radius};
   } else {
      print STDERR "*** Object type $obj->{type} is not support\n";
   }
   return [ ( $xmin, $ymin, $xmax, $ymax ) ];
}

# Convert SVG-line-tag to phun-spring
# INPUT:
#   $obj ... svg object of line
sub svg2phun_Spring {
   my $obj = $_[0];
   my $phun = $Phun[$#Phun];
   &parseSvgId($obj, $phun);
   my @x = ( $obj->{x1}, $obj->{x2} );
   my @y = ( $obj->{y1}, $obj->{y2} );
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   my ( $x0, $x1 ) = @x;
   my ( $y0, $y1 ) = @y;
   $phun->{type} = "addSpring";
   $phun->{distance} = sqrt( ($x0-$x1)**2 + ($y0-$y1)**2 );
   my @color;
   &strokecolor( $obj, \@color );
   $Phun[$#Phun]{color} = \@color;

   my ($id0, $id1);
   my @id0 = &getIncludeObj( $x0, $y0 );
   # $phun->{geom0_} is varid?
   unless ( @id0  && exists $phun->{geom0_} && 
            ( $phun->{geom0_} == 0 || &member($RevHash{$phun->{geom0_}}, \@id0) ) ) {
      delete $phun->{geom0_};
   }

   if ( exists $phun->{geom0_} ) {
      $id0 = $RevHash{ $phun->{geom0_} } unless ($phun->{geom0_} == 0) ;
   } else {
      $id0 = ( @id0 ) ? $id0[ $#id0 ] : undef;
      $phun->{geom0_} = (defined $id0 ) ? ($Phun[$id0]{geomID} or $Phun[$id0]{geomID__}) : 0;
   }

   my @id1 = &getIncludeObj( $x1, $y1 );
   unless ( @id1  && exists $phun->{geom1_} && 
            ( $phun->{geom1_} == 0 || &member($RevHash{$phun->{geom1_}}, \@id1) )) {
      delete $phun->{geom1_};
   }

   if ( exists $phun->{geom1_} ) {
      $id1 = $RevHash{ $phun->{geom1_} } unless ($phun->{geom1_} == 0) ;
   } else {
      $id1 = ( @id1 ) ? $id1[ $#id1 ] : undef;
      $phun->{geom1_} = (defined $id1 ) ? ($Phun[$id1]{geomID} or $Phun[$id1]{geomID__}) : 0;
   }

   if ( defined $id0 ) {
      $phun->{geom0posx} = $x0 - $Phun[ $id0 ]{posx};
      $phun->{geom0posy} = $y0 - $Phun[ $id0 ]{posy};
   } else {
      $phun->{geom0posx} = $x0;
      $phun->{geom0posy} = $y0;
   }
   if ( defined $id1 ) {
      $phun->{geom1posx} = $x1 - $Phun[ $id1 ]{posx};
      $phun->{geom1posy} = $y1 - $Phun[ $id1 ]{posy};
   } else {
      $phun->{geom1posx} = $x1;
      $phun->{geom1posy} = $y1;
   }

   {            # define size (width of line)
      my $width = $SIZE;
      $width = $obj->{'stroke-width'} if (exists $obj->{'stroke-width'});
      ($width) = ($width =~ /($DIGIT)/);   # erase unit
      my @x = ($width);
      my @y = (0);
      &transform($obj, \@x, \@y);
      &transformParentGroup($obj, \@x, \@y);
      $width = sqrt( $x[0]**2 + $y[0]**2 );
      $phun->{size} = $width;
   }
}

# Convert SVG-circle-tag to phun-hinge
# INPUT:
#   $obj ... svg object of circle
sub svg2phun_Hinge {
   my $obj = $_[0];
   my $phun = $Phun[$#Phun];
   my @color;
   &fillcolor( $obj, \@color );
   if ( @color ) {      # This circle is not HINGE
      pop @Phun;      # delete this object.
      return;
   }
   &strokecolor( $obj, \@color );
   $Phun[$#Phun]{color} = \@color;

   &parseSvgId($obj, $phun);

   my $cx = $obj->{cx};
   my $cy = $obj->{cy};
   my $r = $obj->{r};
   &transformCircle($obj, \$cx, \$cy, \$r);
   &transformParentGroupCircle($obj,  \$cx, \$cy, \$r);
   my @id = &getIncludeObj($cx, $cy);

   my ( $id0, $id1 );

   # @id is varid?
   my $varidhinge = 0;
   # hinge is varid for chain!
#   $varidhinge = 1 if (exists $phun->{geom0} && exists $phun->{geom1});
    $varidhinge = 1 if ( @id && 
           exists $phun->{geom0_} && exists $phun->{geom1_}  &&
           ( $phun->{geom0_} == 0 || &member( $RevHash{$phun->{geom0_}}, \@id ) ) &&
           ( $phun->{geom1_} == 0 || &member( $RevHash{$phun->{geom1_}}, \@id ) ));

   if ( $varidhinge ) {
      $id0 = $RevHash{$phun->{geom0_}} unless ($phun->{geom0_} == 0) ;
      $id1 = $RevHash{$phun->{geom1_}} unless ($phun->{geom1_} == 0) ;
   } else {
      if ( $#id >= 1 ) {      # define foot point
         $id0 = $id[$#id  ];
         $id1 = $id[$#id-1];
      } elsif ( $#id == 0 ) {
         $id0 = $id[$#id  ];
         undef $id1;
      } else {
         undef $id0;
         undef $id1;
      }
      $phun->{geom0_} = (defined $id0 ) ? ($Phun[$id0]{geomID} or $Phun[ $id0 ]{geomID__}) : 0;
      $phun->{geom1_} = (defined $id1 ) ? ($Phun[$id1]{geomID} or $Phun[ $id1 ]{geomID__}) : 0;
   }
   if ( defined $id0 ) {
      $phun->{geom0posx} = $cx - $Phun[ $id0 ]{posx};
      $phun->{geom0posy} = $cy - $Phun[ $id0 ]{posy};
   } else {
      $phun->{geom0posx} = $cx;
      $phun->{geom0posy} = $cy;
   }
   if ( defined $id1 ) {
      $phun->{geom1posx} = $cx - $Phun[ $id1 ]{posx};
      $phun->{geom1posy} = $cy - $Phun[ $id1 ]{posy};
   } else {
      $phun->{geom1posx} = $cx;
      $phun->{geom1posy} = $cy;
   }
   $phun->{size} = $r * 2; # diamiter of circle
   $phun->{type} = "addHinge";
   
   $phun->{filter} = $obj->{filter} if exists $obj->{filter}; #for Scene.addWater
}

# Convert Fixjoint from SVG to Phun format.
# INPUT:
#   $obj ... object of polygon 
sub svg2phun_Fixjoint {
   my $obj = $_[0];
   my $phun = $Phun[$#Phun];
   my ( @x, @y, @color );
   &extractXY_from_SVG_polygon($obj->{points}, \@x, \@y);
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   
   unless ( exists $obj->{filter} && $obj->{filter} eq 'fixjoint'){# This object is not Fixjoint　 
      pop @Phun;      # delete this object.
      return;
   }
   
   &strokecolor( $obj, \@color );
   $phun->{color} = \@color;
   
   $phun->{posx} = ($x[0] + $x[1]) / 2;
   $phun->{posy} = ($y[0] + $y[1]) / 2;
   my ($posx, $posy) = ($phun->{posx}, $phun->{posy});
   
   &parseSvgId($obj, $phun);
   my @id = &getIncludeObj($posx, $posy);
   my ( $id0, $id1 );
   
   # @id is varid?
   my $varidfixjoint = 0;
   # hinge is varid for chain!
#   $varidhinge = 1 if (exists $phun->{geom0} && exists $phun->{geom1});
    $varidfixjoint = 1 if ( @id && 
           exists $phun->{geom0_} && exists $phun->{geom1_}  &&
           ( $phun->{geom0_} == 0 || &member( $RevHash{$phun->{geom0_}}, \@id ) ) &&
           ( $phun->{geom1_} == 0 || &member( $RevHash{$phun->{geom1_}}, \@id ) ));

   if ( $varidfixjoint ) {
      $id0 = $RevHash{$phun->{geom0_}} unless ($phun->{geom0_} == 0) ;
      $id1 = $RevHash{$phun->{geom1_}} unless ($phun->{geom1_} == 0) ;
   } else {
      if ( $#id >= 1 ) {      # define foot point
         $id0 = $id[$#id  ];
         $id1 = $id[$#id-1];
      } elsif ( $#id == 0 ) {
         $id0 = $id[$#id  ];
         undef $id1;
      } else {
         undef $id0;
         undef $id1;
      }
      $phun->{geom0_} = (defined $id0 ) ? ($Phun[$id0]{geomID} or $Phun[ $id0 ]{geomID__}) : 0;
      $phun->{geom1_} = (defined $id1 ) ? ($Phun[$id1]{geomID} or $Phun[ $id1 ]{geomID__}) : 0;
   }
   if ( defined $id0 ) {
      $phun->{geom0posx} = $posx - $Phun[ $id0 ]{posx};
      $phun->{geom0posy} = $posy - $Phun[ $id0 ]{posy};
   } else {
      $phun->{geom0posx} = $posx;
      $phun->{geom0posy} = $posy;
   }
   if ( defined $id1 ) {
      $phun->{geom1posx} = $posx - $Phun[ $id1 ]{posx};
      $phun->{geom1posy} = $posy - $Phun[ $id1 ]{posy};
   } else {
      $phun->{geom1posx} = $posx;
      $phun->{geom1posy} = $posy;
   }
   
   $phun->{size} = sqrt(($x[1]-$x[0])**2 + ($y[1]-$y[0])**2) / 2;
   $phun->{type} = "addFixjoint";
}

# Convert SVG-circle-tag to phun-pen
# INPUT:
#   $obj ... svg object of circle
sub svg2phun_Pen {
   my $obj = $_[0];
   my $phun = $Phun[$#Phun];
   my @color;
   &fillcolor( $obj, \@color );
   if ( @color ) {      # This circle is not HINGE
      pop @Phun;      # delete this object.
      return;
   }
   &strokecolor( $obj, \@color );
   $Phun[$#Phun]{color} = \@color;
   
   &parseSvgId($obj, $phun);
   
   my $cx = $obj->{cx};
   my $cy = $obj->{cy};
   my $r = $obj->{r};
   &transformCircle($obj, \$cx, \$cy, \$r);
   &transformParentGroupCircle($obj,  \$cx, \$cy, \$r);
   my @id = &getIncludeObj($cx, $cy);
   
   my $id0;
   
   # @id is varid?
   my $varidPen = 0;
   # hinge is varid for chain!
   #   $varidhinge = 1 if (exists $phun->{geom0} && exists $phun->{geom1});
   $varidPen = 1 if ( @id && exists $phun->{geom0_} &&
           ( $phun->{geom0_} == 0 || &member( $RevHash{$phun->{geom0_}}, \@id ) ) );

   if ( $varidPen ) {
      $id0 = $RevHash{$phun->{geom0_}} unless ($phun->{geom0_} == 0) ;
   } else {
      if ( $#id >= 0 ) {      # define foot point
         $id0 = $id[$#id  ];
      } else {
         undef $id0;
      }
      $phun->{geom0_} = (defined $id0 ) ? ($Phun[$id0]{geomID} or $Phun[ $id0 ]{geomID__}) : 0;
   }
   
   if ( defined $id0 ) {
      $phun->{geom0posx} = $cx - $Phun[ $id0 ]{posx};
      $phun->{geom0posy} = $cy - $Phun[ $id0 ]{posy};
   } else {
      $phun->{geom0posx} = $cx;
      $phun->{geom0posy} = $cy;
   }
   $phun->{size} = $r * 2; # diamiter of circle
   $phun->{type} = "addPen";
   
   $phun->{filter} = $obj->{filter} if exists $obj->{filter}; #for Scene.addWater
}

# get a list of objects including a poing (x, y)
# When no object include the point, return undef.
# INPUT:
#   (x, y) .... cordinates of a test point
# RETURN
#   incObj .... list of element-number of @Phun
sub getIncludeObj {
   my ( $x, $y ) = @_;
   my @incObj;
   my $EPS = 1.e-2;
   foreach ( 0 .. $#Phun ){
      my $obj = $Phun[$_];
      next unless ( exists $obj->{type});
      next unless ( $obj->{type} eq 'addPolygon' ||  $obj->{type} eq 'addCircle' ||  $obj->{type} eq 'addBox');
      my ( $xl, $yl, $xr, $yr) = @{$obj->{boundingbox}};
      next unless ( $x > $xl && $x < $xr && $y > $yl && $y < $yr );
      if ( $obj->{type} eq 'addPolygon' || $obj->{type} eq 'addBox' ) {
         my $theta = 0;
         foreach ( 0 .. $#{$obj->{x}} ) {
            my $l = $_ ==  $#{$obj->{x}} ? 0 : $_+1;
            my $dx1 = $obj->{x}[$l] - $x;
            my $dy1 = $obj->{y}[$l] - $y;
            my $dx0 = $obj->{x}[$_] - $x;
            my $dy0 = $obj->{y}[$_] - $y;
            $theta += atan2( $dx0*$dy1 - $dy0*$dx1, $dx0*$dx1 + $dy0*$dy1);
         }
         next unless ( abs( abs($theta) - 2*$PI ) < $EPS );
         push @incObj, $_;
      } elsif ( $obj->{type} eq 'addCircle' ) {
         next unless ( ($x - $obj->{posx})**2 + ($y - $obj->{posy})**2 <= $obj->{radius}**2 );
         push @incObj, $_;
      } else {
         print STDERR "** Unknown type: $obj->{type}\n";
      }
   }
   return @incObj;
}

# get color vector given by a hex-color code.
# INPUT:
#   $obj ... a svg object
# OUTPUT:
#   $rcolor ... reference to color vector in [0, 1]
#           If the object is decided to be HINGE, a void-array () is returned via $$rcolor.
sub fillcolor {
   my ( $obj, $rcolor ) = @_;

   # for hinge ( fill == none or undef )
   if ( $obj->{-name} eq 'circle' ) {
      @$rcolor = ();
      return if ((! exists $obj->{fill} ) || ( exists $obj->{fill} &&  $obj->{fill} eq 'none' ) );
   }

   my $fill = $FILLCOLOR;                               # default color
   $fill = $obj->{fill} if ( exists $obj->{fill} );
   $fill = $FILLCOLOR if ($fill eq 'none');             # default color
   my $opacity = 1.0;
   $opacity = $obj->{'fill-opacity'} if ( exists $obj->{'fill-opacity'} );
   $opacity = 1.0 if ($opacity eq 'none');
   my ($r, $g, $b) = 
   ($fill =~ /([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])/);
   @$rcolor = sprintf("%.3f, %.3f, %.3f, %.3f", hex($r)/255., hex($g)/255., hex($b)/255., $opacity);

   # stroke property control collide
   my $stroke = "none";
   my $strokeWidth = 1;
   my $strokeDasharray = "none";
   $stroke = $obj->{stroke} if ( exists $obj->{stroke} ) ;
   ( $strokeWidth ) = ( $obj->{'stroke-width'}  =~ /($DIGIT)/) if ( exists $obj->{'stroke-width'} );
   $strokeDasharray = $obj->{'stroke-dasharray'} if ( exists $obj->{'stroke-dasharray'} );

   # collide group A, B, C, D, E
   # Note, when stroke-width < 1 then collideSet = 0.
   if( $stroke eq 'none' ) {
      $Phun[$#Phun]{collideSet} = 0;
      $Phun[$#Phun]{collideWater} = 'false';
   } else {
      {
         # transform storke-width
         my @x = (1, 0, 0);
         my @y = (0, 1, 0);
         &transform($obj, \@x, \@y);
         &transformParentGroup($obj, \@x, \@y);
         # elements of transform array
         my $a = $x[0] - $x[2];
         my $b = $y[0] - $y[2];
         my $c = $x[1] - $x[2];
         my $d = $y[1] - $y[2];
         $strokeWidth = sqrt( abs( $a*$d-$b*$c ) ) * $strokeWidth;
      }
      my $EPS = 1.e-3;
      $strokeWidth = int ($strokeWidth * ( 1 + $EPS));
      $strokeWidth = 1+2+4+8+16 if ( $strokeWidth > 1+2+4+8+16 );
      #$Phun[$#Phun]{collideSet} = $strokeWidth;
      
      # collide with Water
      $Phun[$#Phun]{collideWater} = ($strokeDasharray eq 'none') ? 'true' : 'false';
   }
}

# get color vector given by a hex-color code.
# INPUT:
#   $obj ... a svg object
# OUTPUT:
#   $rcolor ... reference to color vector in [0, 1]
sub strokecolor {
   my ( $obj, $rcolor ) = @_;
   my $stroke = "#000000";                                # default color
   $stroke = $obj->{stroke} if ( exists $obj->{stroke} );
   $stroke = "#000000" if ($stroke eq 'none');                  # default color
   my $opacity = "1.0";
   $opacity = $obj->{'stroke-opacity'} if ( exists $obj->{'stroke-opacity'} );
   $opacity = 1.0 if ($opacity eq 'none');
   my ($r, $g, $b) = ($stroke =~ /([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])/);
   @$rcolor = sprintf("%.3f, %.3f, %.3f, %.3f", hex($r)/255., hex($g)/255., hex($b)/255., $opacity);
}

# get (x, y) coordinates from SVG-path format
#
# INPUT:
#   $points .... a string of coordinates formatted in SVG-path.
# OUTPUT:
#   $rx, $ry ... reference to a array of the coordinates
#
sub extractXY_from_SVG_path {
   my ($points, $rx, $ry) = @_;
   my @points = ( $points =~ /([a-df-zA-DF-Z][0-9., -]+)/g ); # e is excluded for float #
   my ( @x, @y );
   my $xpriv;         # privious x
   my $ypriv;         # privious y
   my $cmdpriv;      # privious command
   my $dirxpriv;      # privious director (x)
   my $dirypriv;      # privious director (y)

   # The fist 'm' is assumed as 'M'.
   # $points[0] =~ s/^m/M/ if ( $points[0] =~ /^m/ );

   foreach my $elem ( @points ) { # ex: M123,456,123,567
#   my @p = ( $elem =~ /([+-]?\d+\.?\d*)/g );
   my @p = &split_digit($elem);
   
   # Moveto (2-elements)  M OK m
   if ( $elem =~ /^M/i ) {
      for (my $n = 0; $n <= $#p; $n += 2) {
         &rel2abs(\@p, $xpriv, $ypriv) if ($elem =~ /^m/);
         push(@x, $p[$n  ]);
         push(@y, $p[$n+1]);
         $xpriv = $x[$#x];
         $ypriv = $y[$#y];
      }
   } 

   # lineto (2-elements) L OK,  l OK
   if ( $elem =~ /^L/i ) {
      for (my $n = 0; $n <= $#p; $n += 2) {
         &rel2abs(\@p, $xpriv, $ypriv) if ($elem =~ /^l/);
         push(@x, $p[$n  ]);
         push(@y, $p[$n+1]);
         $xpriv = $x[$#x];
         $ypriv = $y[$#y];
      }
   } 

   # cubic Bezier curve (6-elements)
   elsif ( $elem =~ /^C/i ) {
      for (my $n = 0; $n <= $#p; $n += 6) {
      &rel2abs(\@p, $xpriv, $ypriv) if ($elem =~ /^c/);
      my @cubic = ($xpriv, $ypriv, @p[$n ... $n + 5]);
      my @lines = Math::Bezier::Convert::cubic_to_lines(@cubic);
      foreach ( 2 .. $#lines) { # skip first anchor
         push(@x, $lines[$_]) if ($_ % 2 == 0);
         push(@y, $lines[$_]) if ($_ % 2 == 1);
      }
      $xpriv = $x[$#x];
      $ypriv = $y[$#y];
      $dirxpriv = $cubic[$#cubic-3];
      $dirypriv = $cubic[$#cubic-2];
      }
   }

   # cubic Bezier curve (short) (4-elements)
   elsif ( $elem =~ /^S/i ) {
      for ( my $n = 0; $n <= $#p; $n += 4) {
      &rel2abs(\@p, $xpriv, $ypriv) if ($elem =~ /^s/);
      my @cubic;
      if ($cmdpriv =~ /^[CS]/i ) {
         @cubic = ($xpriv, $ypriv, 
              2*$xpriv - $dirxpriv, 
              2*$ypriv - $dirypriv, 
              @p[ $n ... $n + 3]);
      } else {
         @cubic = ($xpriv, $ypriv, $xpriv, $ypriv, @p[ $n ... $n + 3]);
      }
      my @lines = Math::Bezier::Convert::cubic_to_lines(@cubic);
      foreach ( 2 .. $#lines ) { # skip first anchor
         push(@x, $lines[$_]) if ($_ % 2 == 0);
         push(@y, $lines[$_]) if ($_ % 2 == 1);
      }
      $xpriv = $x[$#x];
      $ypriv = $y[$#y];
      $dirxpriv = $cubic[$#cubic-3];
      $dirypriv = $cubic[$#cubic-2];
      }
   }

   # quadratic Bezier curve (4-elements)
   elsif ( $elem =~ /^Q/i ) {
      for ( my $n = 0; $n <= $#p; $n += 4) {
      &rel2abs(\@p, $xpriv, $ypriv) if ($elem =~ /^q/);
      my @quadratic = ($xpriv, $ypriv, @p[$n ... $n+3]);
      my @lines = Math::Bezier::Convert::quadratic_to_lines(@quadratic);
      foreach ( 2 .. $#lines ) { # skip first anchor
         push(@x, $lines[$_]) if ($_ % 2 == 0);
         push(@y, $lines[$_]) if ($_ % 2 == 1);
      }
      $xpriv = $x[$#x];
      $ypriv = $y[$#y];
      $dirxpriv = $quadratic[$#quadratic-3];
      $dirypriv = $quadratic[$#quadratic-2];
      }
   } 

   # quadratic Bezier curve (short) (2-elements)
   elsif ( $elem =~ /^T/i ) {
      my @quadratic;
      for ( my $n = 0; $n <= $#p; $n += 2) {
         &rel2abs(\@p, $xpriv, $ypriv) if ($elem =~ /^t/);
         if ($cmdpriv =~ /^[QT]/i ) {
            @quadratic = ($xpriv, $ypriv, 
                 2*$xpriv - $dirxpriv, 
                 2*$ypriv - $dirypriv, 
                 $p[$n], $p[$n + 1] );
         } else {
            @quadratic = ($xpriv, $ypriv, $xpriv, $ypriv, $p[$n], $p[$n + 1]);
         }
         my @lines = Math::Bezier::Convert::quadratic_to_lines(@quadratic);
         foreach ( 2 .. $#lines ) { # skip first anchor
            push(@x, $lines[$_]) if ($_ % 2 == 0);
            push(@y, $lines[$_]) if ($_ % 2 == 1);
         }
         $xpriv = $x[$#x];
         $ypriv = $y[$#y];
         $dirxpriv = $quadratic[$#quadratic-3];
         $dirypriv = $quadratic[$#quadratic-2];
      }
   } 

   # holizontal line ( 1 element)
   elsif ( $elem =~ /^H/i ) {
      foreach ( 0 .. $#p ) {
         $p[$_] = $p[$_] + $xpriv if ($elem =~ /^h/);
         push(@x, $p[$_]);
         push(@y, $ypriv);
         $xpriv = $x[$#x];
         $ypriv = $y[$#y];
      }
   }

   # vertical line ( 1 element)
   elsif ( $elem =~ /^V/i ) {
      foreach ( 0 .. $#p ) {
         $p[$_] = $p[$_] + $ypriv if ($elem =~ /^v/);
         push(@x, $xpriv);
         push(@y, $p[$_]);
         $xpriv = $x[$#x];
         $ypriv = $y[$#y];
      }
   }

   # arcto (7 elements )
   # (rx ry x-axis-rotation large-arc-flag sweep-flag x y)+
   elsif ( $elem =~ /^A/i ) {
      for ( my $n = 0; $n <= $#p; $n += 7) {
         $p[$n + 5] = $p[$n + 5] + $xpriv if ($elem =~ /^a/);
         $p[$n + 6] = $p[$n + 6] + $ypriv if ($elem =~ /^a/);
         my $rx = $p[$n];
         my $ry = $p[$n+1];
         my $phi = $p[$n+2] * $PI / 180.;
         my $fa = $p[$n+3];
         my $fs = $p[$n+4];
         my $x2 = $p[$n+5];
         my $y2 = $p[$n+6];
         my $x1 = $xpriv;
         my $y1 = $ypriv;
         my ($cx, $cy, $theta1, $deltheta);
         {      
            # get center of ellipse, angles of arc
            my $xp =  cos($phi)*($x1-$x2)/2. + sin($phi)*($y1-$y2)/2. ;
            my $yp = -sin($phi)*($x1-$x2)/2. + cos($phi)*($y1-$y2)/2. ; 
            my $a = sqrt(abs($rx**2 * $ry**2 - $rx**2 * $yp**2 - $ry**2 * $xp**2)
                /($rx**2 * $yp**2 + $ry**2 * $xp**2));
            $a = -$a if ($fa == $fs);
            my $cxp =  $a * $rx * $yp / $ry;
            my $cyp = -$a * $ry * $xp / $rx;
            $cx = cos($phi) * $cxp - sin($phi) * $cyp + ($x1 + $x2)/2;
            $cy = sin($phi) * $cxp + cos($phi) * $cyp + ($y1 + $y2)/2;
            # get angle of ellipse
            $theta1 = &angleUV(1., 0., ($xp - $cxp)/$rx, ($yp - $cyp)/$ry);
            $deltheta = &angleUV( ($xp - $cxp)/$rx,  ($yp - $cyp)/$ry, 
                   (-$xp - $cxp)/$rx, (-$yp - $cyp)/$ry);
            if ($fs == 0 && $deltheta > 0) {
               $deltheta = $deltheta - 2*$PI;
            } elsif ($fs == 1 && $deltheta < 0) {
               $deltheta = $deltheta + 2*$PI;
            }
            sub angleUV {
               my($ux, $uy, $vx, $vy) = @_;
               my $del = ($ux*$vx + $uy*$vy)/(sqrt($ux**2+$uy**2)*sqrt($vx**2+$vy**2));
               $del = &acos($del);
               $del = - $del if ( $ux*$vy - $uy*$vx < 0 );
               return $del;
            }
            sub acos { atan2( sqrt(1. - $_[0] * $_[0]), $_[0] ); }
         }
         # plot arc from tehta1 to theta1 + deltheta1
         my $NSEG = int 30*abs($deltheta)/(2*$PI);
         my (@xp, @yp);
         foreach ( 1 .. $NSEG ){
            my $th = $theta1 + $deltheta * $_ / $NSEG;
            my $x = $cx + $rx * cos( $th );
            my $y = $cy + $ry * sin( $th );
            push(@xp, ($x-$cx) * cos($phi) - ($y-$cy) * sin($phi) + $cx);
            push(@yp, ($x-$cx) * sin($phi) + ($y-$cy) * cos($phi) + $cy);
         }
         push(@x, @xp);
         push(@y, @yp);
         $xpriv = $x[$#x];
         $ypriv = $y[$#y];
      }
   }


      ($cmdpriv) = ( $elem =~ /^(.)/);
   # print $cmdpriv, "\n";
   }
   ## remove duplicate point
   {
      my $EPS = 0.01;
      my $xmax = max @x;
      my $xmin = min @x;
      my $ymax = max @y;
      my $ymin = min @y;
      my $epsx = ($xmax - $xmin) * $EPS;
      my $epsy = ($ymax - $ymin) * $EPS;
      if ( abs($x[0] - $x[$#x]) < $epsx && abs($y[0] - $y[$#y]) < $epsy ) {
         my @tmp;
         @tmp = @x[ 0 ... $#x-1 ];
         @x = @tmp;
         @tmp = @y[ 0 ... $#y-1 ];
         @y = @tmp;
      }
   }
   @$rx = @x;
   @$ry = @y;
}

# transform coordinates from relative to absolute systems
# INPUT:
#  (xpriv, ypriv) .... origin of relative coordinate system
# INOUT:
#  rp ................ reference to an array having coordinates.
sub rel2abs {
   my ( $rp, $xpriv, $ypriv ) = @_;
   foreach ( 0 .. $#$rp) {
      $$rp[$_] = $$rp[$_] + $xpriv if ($_ % 2 == 0);
      $$rp[$_] = $$rp[$_] + $ypriv if ($_ % 2 == 1);
   }
}

# get (x, y) coordinates from SVG-polygon format
#
# INPUT:
#   $points .... a string of coordinates formatted in SVG.
# OUTPUT:
#   $rx, $ry ... reference to a array of the coordinates
#
sub extractXY_from_SVG_polygon {
   my ($points, $rx, $ry) = @_;
   my (@x, @y);
   my @points = &split_digit( $points );
   die "** Error on parseing polygon \n"  unless ( @points % 2 == 0 );
   foreach ( 0 .. $#points ) {
      push( @x, $points[$_]) if ($_ % 2 == 0);
      push( @y, $points[$_]) if ($_ % 2 == 1);
   }
   @$rx = @x;
   @$ry = @y;
}

### --- print subroutines --- ###

# print Polygon in phun format
# INPUT:
#   $id ... element number of @Phun
sub printPhunPolygon {
   my $id = $_[0];
   my $objid = $Phun[$id]{id};
   my $color = join(", ", @{ $Phun[$id]{color} } );
   my $rx = $Phun[$id]{x};
   my $ry = $Phun[$id]{y};
   my $posx =  $Phun[$id]{posx} * $SCALE + $XOFFSET;
   my $posy = -$Phun[$id]{posy} * $SCALE + $YOFFSET;
   my $angle = ( exists $Phun[$id]{angle} ) ? $Phun[$id]{angle} : 0.0;
   my $density = ( exists $Phun[$id]{density} ) ? $Phun[$id]{density} : $DENSITY;
   my $friction = ( exists $Phun[$id]{friction} ) ? $Phun[$id]{friction} : $FRICTION;
   my $restitution = ( exists $Phun[$id]{restitution} ) ? $Phun[$id]{restitution} : $RESTITUTION;
   my $geomID = ( exists $Phun[$id]{geomID} ) ?  $Phun[$id]{geomID} : $Phun[$id]{geomID__};
   my $collideSet = ( exists $Phun[$id]{collideSet} ) ?  $Phun[$id]{collideSet} : 1;
   
   foreach ( 0 .. $#{$rx} ) {
      $$rx[$_] =  $$rx[$_] * $SCALE + $XOFFSET;
      $$ry[$_] = -$$ry[$_] * $SCALE + $YOFFSET;
   }
   
   my $vecs = '';
   foreach ( 0 .. $#{$rx} ) {
      my $x = $$rx[$_] - $posx;
      my $y = $$ry[$_] - $posy;
      my $X = $x*cos($angle) + $y*sin($angle);
      my $Y = -$x*sin($angle) + $y*cos($angle);
      $vecs .= "[$X, $Y],"; # (vecs.X, vecs.Y) = ((cos, sin), (-sin, cos)) (x, y)
   }
   chop $vecs;

   my $options = &addtoOptions($Phun[$id], qw( entityID body tracked airFrictionMult controllerAcc controllerReverseXY controllerInvertX controllerInvertY heteroCollide zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror forceController ) );
   
   print <<"PHUN";
Scene.addPolygon {
   geomID = $geomID;
   angle = $angle;
   collideSet = $collideSet;
   collideWater = $Phun[$id]{collideWater};
   color = [$color];
   density = $density;
   friction = $friction;
   pos = [$posx, $posy];
   restitution = $restitution;
   vecs = [$vecs];
$options};
PHUN
}

# print Box in phun format
# INPUT:
#   $id ... element number of @Phun
sub printPhunBox {
   my $id = $_[0];
   my $objid = $Phun[$id]{id};
   my $color = join(", ", @{ $Phun[$id]{color} } );
   my $rx = $Phun[$id]{x};
   my $ry = $Phun[$id]{y};
   my $posx =  $Phun[$id]{posx} * $SCALE + $XOFFSET;
   my $posy = -$Phun[$id]{posy} * $SCALE + $YOFFSET;
   #my $angle = ( exists $Phun[$id]{angle} ) ? $Phun[$id]{angle} : 0.0;
   my $density = ( exists $Phun[$id]{density} ) ? $Phun[$id]{density} : $DENSITY;
   my $friction = ( exists $Phun[$id]{friction} ) ? $Phun[$id]{friction} : $FRICTION;
   my $restitution = ( exists $Phun[$id]{restitution} ) ? $Phun[$id]{restitution} : $RESTITUTION;
   my $geomID = ( exists $Phun[$id]{geomID} ) ?  $Phun[$id]{geomID} :  $Phun[$id]{geomID__};
   my $collideSet = ( exists $Phun[$id]{collideSet} ) ?  $Phun[$id]{collideSet} : 1;
   
   foreach ( 0 .. $#{$rx} ) {
      $$rx[$_] =  $$rx[$_] * $SCALE + $XOFFSET - $posx;
      $$ry[$_] = -$$ry[$_] * $SCALE + $YOFFSET - $posy;
   }
   my $width = sqrt(($$rx[1] - $$rx[0])**2 + ($$ry[1] - $$ry[0])**2);
   my $height = sqrt(($$rx[3] - $$rx[0])**2 + ($$ry[3] - $$ry[0])**2);
   my $size = "[$width, $height]";
   my $angle = atan2(($$ry[1] - $$ry[0]), ($$rx[1] - $$rx[0]));
   
   my $options = &addtoOptions($Phun[$id], qw( entityID body tracked airFrictionMult controllerAcc controllerReverseXY controllerInvertX controllerInvertY heteroCollide zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror forceController ) );
   
   print <<"PHUN";
Scene.addBox {
   geomID = $geomID;
   angle = $angle;
   collideSet = $collideSet;
   collideWater = $Phun[$id]{collideWater};
   color = [$color];
   density = $density;
   friction = $friction;
   pos = [$posx, $posy];
   restitution = $restitution;
   size = $size;
$options};
PHUN
}

# print Circle in phun format
# INPUT:
#   $id ... element number of @Phun
sub printPhunCircle {
   my $id = $_[0];
   my $objid = $Phun[$id]{id};
   my $color = join(", ", @{ $Phun[$id]{color} } );
   my $posx =  $Phun[$id]{posx} * $SCALE + $XOFFSET;
   my $posy = -$Phun[$id]{posy} * $SCALE + $YOFFSET;
   my $radius = $Phun[$id]{radius} * $SCALE;
   my $angle =  ( exists $Phun[$id]{angle} ) ? $Phun[$id]{angle} : $ANGLE;
   my $density = ( exists $Phun[$id]{density} ) ? $Phun[$id]{density} : $DENSITY;
   my $friction = ( exists $Phun[$id]{friction} ) ? $Phun[$id]{friction} : $FRICTION;
   my $restitution = ( exists $Phun[$id]{restitution} ) ? $Phun[$id]{restitution} : $RESTITUTION;
   my $geomID = ( exists $Phun[$id]{geomID} ) ?  $Phun[$id]{geomID} :  $Phun[$id]{geomID__};
   my $collideSet = ( exists $Phun[$id]{collideSet} ) ?  $Phun[$id]{collideSet} : 1;
   
   my $options = &addtoOptions($Phun[$id], qw( entityID body tracked airFrictionMult controllerAcc controllerReverseXY controllerInvertX controllerInvertY heteroCollide zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror forceController ) );
   
   if ( exists $Phun[$id]{filter} && $Phun[$id]{filter} eq 'water'){
      $Phun_addWater .= ', [' . $posx . ', ' . $posy . ']';
      return;
   }
   
   print <<"PHUN";
Scene.addCircle {
   geomID = $geomID;
   angle = $angle;
   collideSet = $collideSet;
   collideWater = $Phun[$id]{collideWater};
   color = [$color];
   density = $density;
   friction = $friction;
   pos = [$posx ,$posy];
   radius = $radius;
   restitution = $restitution;
$options};
PHUN
}

# print Plane in phun format
#
# INPUT:
#   $id ... element number of @Phun
#
sub printPhunPlane {
   my $id = $_[0];
   my $objid = $Phun[$id]{id};
   my $color = join(", ", @{ $Phun[$id]{color} } );
   my $posx =  $Phun[$id]{posx} * $SCALE + $XOFFSET;
   my $posy = -$Phun[$id]{posy} * $SCALE + $YOFFSET;
   
   my $friction = ( exists $Phun[$id]{friction} ) ? $Phun[$id]{friction} : $FRICTION;
   my $restitution = ( exists $Phun[$id]{restitution} ) ? $Phun[$id]{restitution} : $RESTITUTION;
   my $angle = $Phun[$id]{angle};
   my $collideSet = ( exists $Phun[$id]{collideSet} ) ?  $Phun[$id]{collideSet} : 1 - 32;
   
   my $options = &addtoOptions($Phun[$id], qw( geomID entityID body tracked heteroCollide zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror ) );
   
   print <<"PHUN";
Scene.addPlane{
   angle = $angle;
   collideSet = $collideSet;
   collideWater = $Phun[$id]{collideWater};
   color = [$color];
   friction = $friction;
   pos = [$posx ,$posy];
   restitution = $restitution;
$options};
PHUN
}


# print Spring in phun format
#
# INPUT:
#   $id ... element number of @Phun
#
sub printPhunSpring {
   my $id = $_[0];
   my $geom0posx =  $Phun[$id]{geom0posx} * $SCALE;
   my $geom0posy = -$Phun[$id]{geom0posy} * $SCALE;
   my $geom1posx =  $Phun[$id]{geom1posx} * $SCALE;
   my $geom1posy = -$Phun[$id]{geom1posy} * $SCALE;
   my $size = $Phun[$id]{size} * $SCALE * $PerPoint;
   my $dampingFactor = ( defined $Phun[$id]{dampingFactor} ) ? $Phun[$id]{dampingFactor} : $DAMPINGFACTOR;
   my $length = ( defined $Phun[$id]{length} ) ? $Phun[$id]{length} : $Phun[$id]{distance} * $SCALE;
   my $strengthFactor = ( defined $Phun[$id]{strengthFactor} ) ? $Phun[$id]{strengthFactor} : $STRENGTHFACTOR;

   
   my $geom0 = ( defined $Phun[$id]{geom0} ) ? $Phun[$id]{geom0} : $Phun[$id]{geom0_}; 
   my $geom0pos = ( defined $Phun[$id]{geom0pos} ) ? $Phun[$id]{geom0pos} : "[".$geom0posx.", ".$geom0posy."]";
   my $geom1 = ( defined $Phun[$id]{geom1} ) ? $Phun[$id]{geom1} : $Phun[$id]{geom1_}; 
   my $geom1pos = ( defined $Phun[$id]{geom1pos} ) ? $Phun[$id]{geom1pos} : "[".$geom1posx.", ".$geom1posy."]";
   
   #my $color = ( defined $Phun[$id]{color} ) ? $Phun[$id]{color} : $SPRINGCOLOR;
   #my $opacity = ( defined $Phun[$id]{opacity} ) ? $Phun[$id]{opacity} : 1.0;
   #my ($r, $g, $b) = 
   #   ($color =~ /([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])/);
   #$color = sprintf("%.3f, %.3f, %.3f, %.3f", hex($r)/255., hex($g)/255., hex($b)/255., $opacity);
   my $color = join(", ", @{ $Phun[$id]{color} } );
   
   my $options = &addtoOptions($Phun[$id], qw( entityID tracked zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror ) );
   
   print <<"PHUN";
Scene.addSpring {
   color = [$color];
   dampingFactor = $dampingFactor;
   geom0 = $geom0;
   geom0pos = $geom0pos;
   geom1 = $geom1;
   geom1pos = $geom1pos;
   length = $length;
   size = $size;
   strengthFactor = $strengthFactor;
$options};
PHUN
}

# print Hinge in phun format
# INPUT:
#   $id ... element number of @Phun
sub printPhunHinge {
   my $id = $_[0];
   my $geom0posx =  $Phun[$id]{geom0posx} * $SCALE;
   my $geom0posy = -$Phun[$id]{geom0posy} * $SCALE;
   my $geom1posx =  $Phun[$id]{geom1posx} * $SCALE;
   my $geom1posy = -$Phun[$id]{geom1posy} * $SCALE;
   my $size = $Phun[$id]{size} * $SCALE;
   my $ccw = ( defined $Phun[$id]{ccw} ) ? $Phun[$id]{ccw} : $CCW;

   my $motor = ( defined $Phun[$id]{motor} ) ? $Phun[$id]{motor} : $MOTOR;
   my $motorSpeed = ( defined $Phun[$id]{motorSpeed} ) ? $Phun[$id]{motorSpeed} : $MOTORSPEED;
   my $motorTorque = ( defined $Phun[$id]{motorTorque} ) ? $Phun[$id]{motorTorque} : $MOTORTORQUE;
   
   my $geom0 = ( defined $Phun[$id]{geom0} ) ? $Phun[$id]{geom0} : $Phun[$id]{geom0_}; 
   my $geom0pos = ( defined $Phun[$id]{geom0pos} ) ? $Phun[$id]{geom0pos} : "[".$geom0posx.", ".$geom0posy."]";
   my $geom1 = ( defined $Phun[$id]{geom1} ) ? $Phun[$id]{geom1} : $Phun[$id]{geom1_}; 
   my $geom1pos = ( defined $Phun[$id]{geom1pos} ) ? $Phun[$id]{geom1pos} : "[".$geom1posx.", ".$geom1posy."]";
   
   my $color = join(", ", @{ $Phun[$id]{color} } );
   
   my $options = &addtoOptions($Phun[$id], qw( autoBrake distanceLimit impulseLimit entityID tracked zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror buttonBack buttonBrake buttonForward ) );
   
   if ( exists $Phun[$id]{filter} && $Phun[$id]{filter} eq 'water'){
      $Phun_addWater .= ', [' . $geom0posx . ', ' . $geom0posy . ']';
      return;
   }
   
   print <<"PHUN";
Scene.addHinge {
   ccw = $ccw;
   color = [$color];
   geom0 = $geom0;
   geom0pos = $geom0pos;
   geom1 = $geom1;
   geom1pos = $geom1pos;
   motor = $motor;
   motorSpeed = $motorSpeed;
   motorTorque = $motorTorque;
   size = $size;
$options};
PHUN
}

# print Hinge in phun format
# INPUT:
#   $id ... element number of @Phun
sub printPhunFixjoint {
   my $id = $_[0];
   my $geom0posx =  $Phun[$id]{geom0posx} * $SCALE;
   my $geom0posy = -$Phun[$id]{geom0posy} * $SCALE;
   my $geom1posx =  $Phun[$id]{geom1posx} * $SCALE;
   my $geom1posy = -$Phun[$id]{geom1posy} * $SCALE;
   my $size = $Phun[$id]{size} * $SCALE;
   
   my $geom0 = ( defined $Phun[$id]{geom0} ) ? $Phun[$id]{geom0} : $Phun[$id]{geom0_}; 
   my $geom0pos = ( defined $Phun[$id]{geom0pos} ) ? $Phun[$id]{geom0pos} : "[".$geom0posx.", ".$geom0posy."]";
   my $geom1 = ( defined $Phun[$id]{geom1} ) ? $Phun[$id]{geom1} : $Phun[$id]{geom1_}; 
   my $geom1pos = ( defined $Phun[$id]{geom1pos} ) ? $Phun[$id]{geom1pos} : "[".$geom1posx.", ".$geom1posy."]";
   
   my $color = join(", ", @{ $Phun[$id]{color} } );
   
   my $options = &addtoOptions($Phun[$id], qw( entityID tracked zDepth ) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror ) );
   
   print <<"PHUN";
Scene.addFixjoint {
   color = [$color];
   geom0 = $geom0;
   geom0pos = $geom0pos;
   geom1 = $geom1;
   geom1pos = $geom1pos;
   size = $size;
$options};
PHUN
}

# print Hinge in phun format
#
# INPUT:
#   $id ... element number of @Phun
#
sub printPhunPen {
   my $id = $_[0];
   my $geom0posx =  $Phun[$id]{geom0posx} * $SCALE;
   my $geom0posy = -$Phun[$id]{geom0posy} * $SCALE;
   my $size = $Phun[$id]{size} * $SCALE;
   
   my $geom = ( defined $Phun[$id]{geom} ) ? $Phun[$id]{geom} : $Phun[$id]{geom0_}; 
   my $relPoint = ( defined $Phun[$id]{relPoint} ) ? $Phun[$id]{relPoint} : "[".$geom0posx.", ".$geom0posy."]";
   
   #my $color = ( defined $Phun[$id]{color} ) ? $Phun[$id]{color} : $HINGECOLOR;
   #my $opacity = ( defined $Phun[$id]{opacity} ) ? $Phun[$id]{opacity} : 1.0;
   #
   #my ($r, $g, $b) = 
   #   ($color =~ /([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])/);
   #$color = sprintf("%.3f, %.3f, %.3f, %.3f", hex($r)/255., hex($g)/255., hex($b)/255., $opacity);
   
   my $color = join(", ", @{ $Phun[$id]{color} } );
   my $options = &addtoOptions($Phun[$id], qw( entityID tracked fadeTime zDepth) );
   $options .= &addtoButtonOptions($Phun[$id], qw( buttonDestroy buttonMirror ) );
   
   if ( exists $Phun[$id]{filter} && $Phun[$id]{filter} eq 'water'){
      $Phun_addWater .= ', [' . $geom0posx . ', ' . $geom0posy . ']';
      return;
   }
   
   print <<"PHUN";
Scene.addPen {
   color = [$color];
   geom = $geom;
   relPoint = $relPoint;
   size = $size;
$options};
PHUN
}

# get baricenter
# INPUT:
#   $rx, $ry ....  the coordinates of path (reference of arrary)
# OUTPU;
#   $rxg, $ryg .... references of coordinates of the baricenter.
sub baricenter {
   my ($rx, $ry, $rxg, $ryg) = @_;
   my $EPS = 0.00001;
   my $sumx = 0;
   my $sumy = 0;
   my $sums = 0;
   foreach ( 0 .. $#$rx ) {
      my $j = $_ + 1;
      $j = 0 if ( $j == $#$rx+1 );
      my $pp = $$rx[$_] * $$ry[$j] - $$rx[$j] * $$ry[$_];
      $sums += $pp;
      $sumx += $pp*( $$rx[$_] + $$rx[$j]);
      $sumy += $pp*( $$ry[$_] + $$ry[$j]);
   }

   my $ix1 = 1./6.* $sumx;
   my $iy1 = 1./6.* $sumy;
   my $surf = 0.5 * $sums;
   if ( $surf == 0 ) { 
      print STDERR "*** Warning in baricenter\n";
      $surf = $EPS 
   };
   $$rxg = $ix1 / $surf;
   $$ryg = $iy1 / $surf;
}

# -------------------------------------------------
#  transform subroutines
# -------------------------------------------------
sub transformParentGroupCircle {
   my ( $obj, $cx, $cy, $r ) = @_;
   my (@xp, @yp);
   @xp = ( $$cx, $$cx+$$r );
   @yp = ( $$cy, $$cy );
   &transformParentGroup($obj, \@xp, \@yp);
   $$cx = $xp[0];
   $$cy = $yp[0];
   $$r = sqrt(($xp[1]-$xp[0])**2+($yp[1]-$yp[0])**2);
}

sub transformParentGroup {
   my ( $obj, $rx, $ry ) = @_;
   my $this = $obj;
   while ( exists $this->{-parent} && $this->{-parentname} eq 'g' ) {
      &transform($this->{-parent}, $rx, $ry) if ( exists $this->{-parent}{transform} );
      $this = $this->{-parent} 
   }
}
sub transformCircle {
   my ( $obj, $cx, $cy, $r ) = @_;
   my (@xp, @yp);
   @xp = ( $$cx, $$cx+$$r );
   @yp = ( $$cy, $$cy );
   &transform ($obj, \@xp, \@yp);
   $$cx = $xp[0];
   $$cy = $yp[0];
   $$r = sqrt(($xp[1]-$xp[0])**2+($yp[1]-$yp[0])**2);
}

sub transform {
   my ( $obj, $rx, $ry ) = @_;
   return unless ( exists $obj->{transform} );
   if ($obj->{transform} =~ /^matrix/) {
      my ($a, $b, $c, $d, $e, $f) = &split_digit($obj->{transform});
      &trans_matrix($a, $b, $c, $d, $e, $f, $rx, $ry);
   } elsif ($obj->{transform} =~ /^translate/) {
      my ($tx,  $ty) = &split_digit($obj->{transform});
      &trans_translate($tx, $ty, $rx, $ry);
   } elsif ($obj->{transform} =~ /^scale/) {
      my ($sx,  $sy) = &split_digit($obj->{transform});
      &trans_scale($sx, $sy, $rx, $ry);
   } elsif ($obj->{transform} =~ /^rotate/) {
      my ($a, $cx, $cy) = &split_digit($obj->{transform});
      if ( defined $cx && defined $cy) {
         &trans_translate(-$cx, -$cy, $rx, $ry);
         &trans_rotate($a, $rx, $ry);
         &trans_translate($cx, $cy, $rx, $ry);
      } else {
         &trans_rotate($a, $rx, $ry);
      }
   } elsif ($obj->{transform} =~ /^skewX/) {
      my ($a) = &split_digit($obj->{transform});
      &trans_skewx($a, $rx, $ry);
   } elsif ($obj->{transform} =~ /^skewY/) {
      my ($a) =  &split_digit($obj->{transform});
      &trans_skewy($a, $rx, $ry);
   }
}

sub trans_matrix  {
   my ($a, $b, $c, $d, $e, $f, $rx, $ry) = @_; 
   foreach ( 0 .. $#$rx){
      my $x = $$rx[$_];
      my $y = $$ry[$_];
      $$rx[$_] = $a * $x + $c * $y + $e;
      $$ry[$_] = $b * $x + $d * $y + $f;
   }
}
sub trans_translate {
   my ($tx, $ty, $rx, $ry) = @_;
   $ty = 0 if (!defined $ty);
   &trans_matrix(1, 0, 0, 1, $tx, $ty, $rx, $ry);
}
sub trans_scale {
   my ($sx, $sy, $rx, $ry) = @_;
   $sy = $sx if (!defined $sy);
   &trans_matrix($sx, 0, 0, $sy, 0, 0, $rx, $ry);
}
sub trans_rotate {
   my ($a, $rx, $ry) = @_;
   $a = $a * $PI / 180;
   &trans_matrix(cos($a), sin($a), -sin($a), cos($a), 0, 0, $rx, $ry);
}
sub trans_skewx {
   my ($a, $rx, $ry) = @_;
   $a = $a * $PI / 180;
   &trans_matrix(1, 0, tan($a), 1, 0, 0, $rx, $ry);
}
sub trans_skewy {
   my ($a, $rx, $ry) = @_;
   $a = $a * $PI / 180;
   &trans_matrix(1, tan($a), 0, 1, 0, 0, $rx, $ry);
}

# substract digits (integer and float, ..) from a stirng,
# and returns a list of degits.
sub split_digit {
   my $str = $_[0];
   my @list;
   while ( $str =~ s/($DIGIT)//) {
      push @list, $1;
   }
   return @list;
}

# Reform parameters of objects
# At this time, renumber of ID numbers to avoid duplicate numbers.
sub reformParameter {
   # id
   my %seen;
   my $maxid = 0;
   foreach (0 .. $#Phun ) { # search duplicated ID
      my $obj = $Phun[$_];
      next unless ($obj->{type} eq 'addCircle' ||$obj->{type} eq 'addBox' || $obj->{type} eq 'addPolygon' || $obj->{type} eq 'addPlane');
      next unless ( defined $obj->{id} );
      $seen{ $obj->{id} }++;
      $maxid = $obj->{id} if ( $obj->{id} > $maxid );
      $obj->{id} = undef if ($seen{ $obj->{id} } >= 2);
   }
   my $id = 1;
   $id = $IDOFFSET if ($maxid == 0);      # no ID exists. 
   foreach ( 0 .. $#Phun ) { # renumber
      my $obj = $Phun[$_];
      next unless ($obj->{type} eq 'addCircle' ||$obj->{type} eq 'addBox' || $obj->{type} eq 'addPolygon' || $obj->{type} eq 'addPlane');
      next if  ( defined $obj->{id} );
      $obj->{id} = $maxid + $id;
      $id++;
   }
}

sub mkRevhash {
   foreach ( 0 .. $#Phun ){
      $RevHash{ $Phun[$_]{id} } = $_ if (exists $Phun[$_]{id});
   }
}

# returns group id (body)
# INPUT:
#    obj ........... a SVG-object
# INOUT
#    rgroupIdMax ... maximum of group id (reference)
# RETURN:
#    group id
#    -1 means "this obj isn't in any groups"
sub getGroupID {
   my ($obj, $rgroupIdMax) = @_;
   if ( exists $obj->{-name} &&  $obj->{-name} eq 'g' && 
         exists $obj->{id} && $obj->{id} =~ /^body:(\d+)/ ) {
      return $1;
   } else {
      $$rgroupIdMax++;
      return $$rgroupIdMax;
   }
}
# -------------------------------------------------------------------
# reform Inkscape tags, converting inkscape tags to illustrator tags
# INPUT:
#   root svg object
# -------------------------------------------------------------------
sub reformInkscapeTags {
   my $tags = $_[0];
   foreach ( 0 .. $#$tags ) {
      my $tag = $tags->[$_];
      if ( $tag->{-name} eq 'g' ) {
         &reformInkscapeTags( $tag->{-childs} );
      } else {
         &reformInkscapeTag($tag);
      }
   }
}

# reform an Inkscape tag
# INPUT:
#   a svg-object
sub reformInkscapeTag {
   my $tag = $_[0];
   &reformInkscapeStyle($tag);
   return if &reformInkscapeCircle($tag);
   return if &reformInkscapeLine($tag);
}

sub  reformInkscapeCircle {
   my $obj = $_[0];
   return 0 unless (exists $obj->{'sodipodi:type'} && $obj->{'sodipodi:type'} eq 'arc');
   return 0 unless (exists $obj->{'sodipodi:rx'} &&  exists $obj->{'sodipodi:ry'});
   return 0 unless ($obj->{'sodipodi:rx'} eq $obj->{'sodipodi:ry'});
   return 0 if (exists $obj->{'sodipodi:start'});
   return 0 if (exists $obj->{'sodipodi:end'});
   if ( exists $obj->{transform} ) {
      if ($obj->{transform} =~ /^matrix/) {
         my ($a, $b, $c, $d, $e, $f) = &split_digit($obj->{transform});
         return 0 unless ($a eq $d); # eval in strings
         $b =~ s/^[-+]//;
         $c =~ s/^[-+]//;
         return 0 unless ($b eq $c);
      } elsif ($obj->{transform} =~ /^scale/) {
         my ($sx,  $sy) = &split_digit($obj->{transform});
         return 0 unless ($sx eq $sy);
      } elsif ($obj->{transform} =~ /^skew/) {
         return 0;
      }
   }
   $obj->{-name} = 'circle';
   $obj->{r} = $obj->{'sodipodi:rx'};
   $obj->{cx} = $obj->{'sodipodi:cx'};
   $obj->{cy} = $obj->{'sodipodi:cy'};
   return 1;
}

sub  reformInkscapeLine {
   my $obj = $_[0];
   return 0 unless ( $obj->{-name} eq 'path' );
   return 0 unless ( $obj->{d} =~ /^M( ?$DIGIT,? ?)+L( ?$DIGIT,? ?)+z? *$/i );
   my (@x, @y);
   &extractXY_from_SVG_path($obj->{d}, \@x, \@y);

   $obj->{x1} = $x[0];
   $obj->{y1} = $y[0];
   $obj->{x2} = $x[1];
   $obj->{y2} = $y[1];
   $obj->{-name} = 'line';
   return 1;
}

sub reformInkscapeStyle {
   my $obj = $_[0];
   return 0 unless ( exists $obj->{style} );
   my $style = $obj->{style};
   $obj->{fill} = $style->{fill} if ( exists $style->{fill} );
   $obj->{stroke} = $style->{stroke} if ( exists $style->{stroke} );
   $obj->{'stroke-width'} = $style->{'stroke-width'} if ( exists $style->{'stroke-width'} );
   $obj->{'stroke-dasharray'} = $style->{'stroke-dasharray'} if ( exists $style->{'stroke-dasharray'} );
   $obj->{'fill-opacity'} = $style->{'fill-opacity'} if ( exists $style->{'fill-opacity'} );
   $obj->{'stroke-opacity'} = $style->{'stroke-opacity'} if ( exists $style->{'stroke-opacity'} );
   if ( exists $style->{opacity} ) {
      $obj->{'fill-opacity'} *= $style->{opacity};
      $obj->{'stroke-opacity'} *= $style->{opacity};
   }
   return 1;
}

sub member {
   my ( $test, $list ) = @_;
   foreach my $elem ( @$list ) {
      return 1 if ($test == $elem) ;
   }
   return 0;
}

sub isPlaneOrSpring {
   my $obj = $_[0];
   return 0 unless ($obj->{-name} eq 'line');
   my @x = ( $obj->{x1}, $obj->{x2} );
   my @y = ( $obj->{y1}, $obj->{y2} );
   &transform($obj, \@x, \@y);
   &transformParentGroup($obj, \@x, \@y);
   my ( $x0, $x1 ) = @x;
   my ( $y0, $y1 ) = @y;
   my @id0 = &getIncludeObj( $x0, $y0 );
   my @id1 = &getIncludeObj( $x1, $y1 );
   if ( @id0 ==0 && @id1 == 0) {
      return 'addPlane';
   } else {
      return 'addSpring';
   }
}

sub addtoOptions {
   my ( $obj, @options ) = @_;
   my $ret ='';
   foreach my $opt (@options) {
      $ret .= "   $opt= $obj->{$opt};\n" if (exists $obj->{$opt});
   }
   return $ret;
}

sub addtoButtonOptions {
   my ( $obj, @options ) = @_;
   my $ret ='';
   foreach my $opt (@options) {
      $ret .= "   $opt= \"$obj->{$opt}\";\n" if (exists $obj->{$opt});
   }
   return $ret;
}
