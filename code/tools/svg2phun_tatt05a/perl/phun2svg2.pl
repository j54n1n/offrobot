#! /usr/bin/perl -w
#
# last updated : 2008/10/26
#
# This script converts data from Phun format to SVG format for phn-file-'FileInfo.version = 2'.
#
# Usage:
#   phun2svg2.pl file.svg
#               http://www.sakai.zaq.ne.jp/dugyj708/svg2phun_tatt/index.html 
#
# About SVG2Phun2: tatt61880
#              http://www.sakai.zaq.ne.jp/dugyj708/svg2phun_tatt/index.html
# 
# About SVG2Phun: t0m0tomo
#              http://www.nicovideo.jp/watch/sm2589929
#              http://youtube.com/watch?v=PPhOBfFEjHA
#              http://www.geocities.jp/int_real_float/svg2phun/

use SVG;
use List::Util qw(max min);
use strict;
#use Data::Dumper;

# conversion parameters (default)
my $SCALE = 1/72.;
my $PerPoint = 2;
my $XOFFSET = 0;
my $YOFFSET = 0;
my $RESOLUTION = [1280, 1024];
my $SVG_PAN = [undef,undef];
my $ZOOM = 1;
my $DIGIT = '[+-]?(\d+\.\d+|\d+\.|\.\d+|\d+)([eE][+-]?\d+)?'; # regexp for digit (int, float)
my $PLANELENGTHFACTOR = 1.5;
my $CAMERA = undef;
my $CAMERA_X = 0;
my $CAMERA_Y = 0;
my $LASTzDEPTH = -1;

### Read phn file ###
die "Usage: $0 file.phn\n" unless @ARGV;
my $infile = $ARGV[0];
die "Usage: $0 file.phn\n" unless ($infile =~ /\.phn$/i);
die "$ARGV[0] is not found.\n" unless (-e $ARGV[0]);

&readConf;
@$RESOLUTION[0] /= 2;
@$RESOLUTION[1] /= 2;

## read configuration file
sub readConf {
   my $conffile = 'config.txt';
   my $dir = $0;
   local $/=undef;
   $dir =~ s#[^/\\]+$##;
   $conffile = $dir . $conffile;
   open( F, "$conffile") or return; #die $!, "$conffile\n";
   print STDERR "Reading configuration file $conffile\n";
   my $conftxt = <F>;
   close F;
   $conftxt = $1 if ($conftxt =~ m{<phun2svg2>([\d\D]*)</phun2svg2>}g);
   eval($conftxt);
}

my @Phun;
my %RevHash;
my %Group;
my %Id;            # pseudo-id for hinge and spring
my $Phun_config = "";   # thyme script except "Scene.add__{};" and "Keys.bind{};" command.
my @Phun_addGroup;
my @Phun_addWidget;

{
   local $/=undef;
   
   my $phun=<>;
   $phun =~ s/forceController\s*=\s*"keys (\w+) (\w+) (\w+) (\w+)"/forceController = "keys,$1,$2,$3,$4"/g;
   my @lines = split /\n/, $phun;
   foreach my $line ( @lines ) {
      &execute_phun2svg($0, $infile) if($line =~ /^version = 1;$/);
      if($line =~ /^Scene.Camera.pan = \[($DIGIT), ($DIGIT)\];/){
         ($CAMERA_X, $CAMERA_Y) = ($1, $4);
         $CAMERA = 'true';
      } elsif ($line =~ /(^[A-Z][^\n]+;$)/ && !($line =~ /^Scene.addWater/)){
         $Phun_config .= "<!-- PHUN THYME $1 -->\n";
         $ZOOM = $1 / 150 if($line =~ /^Scene.Camera.zoom = ($DIGIT);/);
      }
   }
   @$SVG_PAN[0] = @$RESOLUTION[0] / $ZOOM;
   @$SVG_PAN[1] = @$RESOLUTION[1] / $ZOOM;
   $XOFFSET = $CAMERA_X - (@$RESOLUTION[0] / $ZOOM * $SCALE / 2);
   $YOFFSET = $CAMERA_Y + (@$RESOLUTION[1] / $ZOOM * $SCALE / 2);
   if($CAMERA){
      my ($camera_x, $camera_y) = (@$SVG_PAN[0] * $SCALE / 2, -@$SVG_PAN[1] * $SCALE / 2);
      $Phun_config .= "<!-- PHUN THYME Scene.Camera.pan = [$camera_x, $camera_y]; -->\n";
   }
   @Phun_addGroup = ($phun =~ /Scene\.addGroup\s+{([^}{]+)}/g); # {}の中身を取り出す。
   @Phun_addWidget = ($phun =~ /Scene\.addWidget\s+{([^}{]+)}/g);
   &phunParse ($phun, \@Phun);
}
&sortPhun(\@Phun);
&defineGroup(\@Phun, \%Group);
&extendPlane(\@Phun);
my $Svg = SVG->new(
                     width => @$SVG_PAN[0],
                     height => @$SVG_PAN[1],
                     );
&Tags($Svg, \@Phun, \%Group);

#print Dumper(@Phun);
#print Dumper(\%Group);

## output file
{
   my $outfile = $infile;
   $outfile =~ s/(\(\d+\))?\.phn$//i;
   unless ( -f "$outfile.svg" ) {
      $outfile = "$outfile.svg";
   } else {
      my $n=1;
      $n++  while ( -f "$outfile($n).svg" );
      $outfile = "$outfile($n).svg";
   }
   print STDERR "Outputing data to $outfile\n";
   open ( F, ">$outfile") or die $!, " $outfile\n";
   my $Oldfh = select (STDOUT);
   select F;
   print $Svg->xmlify;
   print "\n";
   print "<!-- PHUN ADDGROUP " . $_ . " -->\n" foreach (@Phun_addGroup);
   print "<!-- PHUN ADDWIDGET " . $_ . " -->\n" foreach (@Phun_addWidget);
   print $Phun_config;
   print "<!-- Phun scene created by phun2svg2 -->\n";
   select $Oldfh;
   close F;
}
exit;

# Parse a phun data set so that $Phun[ #obj ]{type} = polygon
# INPUT: 
#   phun ..... a phun data set in strings
# OUTPUT:
#   rPhun .... Parsed data (reference to @Phun)
sub phunParse {
   my ($phun, $rPhun) = @_;
   $phun =~ s/\r//g;
   $phun =~ s/\n\s*//g;
   $phun =~ s/\s*=\s*/=/g;
   
   my @objs = ($phun =~ /(Scene\.add\w+\s*{[^}{]+)}/g);
   foreach ( 0 .. $#objs ) {
      my $obj = $objs[$_];
      my $robj;
      $obj =~ s/Scene\.(add\w+)\s*{/type=$1;/;
      foreach ( split(';', $obj) ) {
         my ($key, $val) = split(/=/, $_);
         $val =~ s/"//g;
         $robj->{$key} = $val;
      }
      if ($robj->{type} eq 'addPolygon') { #Polygon
         &parseColor($robj);
         &parsePos($robj);
         &parseVecs($robj) ;
         push @$rPhun, $robj;
         if (exists $robj->{geomID} ){
            $RevHash{ $robj->{geomID}} =  $#$rPhun;
         } else {
            $RevHash{ $_} =  $#$rPhun;
         }
      }
      elsif ($robj->{type} eq 'addBox') { #Box
         &parseColor($robj);
         &parsePos($robj);
         &parseBox($robj) ;
         push @$rPhun, $robj;
         if (exists $robj->{geomID} ){
            $RevHash{ $robj->{geomID}} =  $#$rPhun;
         } else {
            $RevHash{ $_} =  $#$rPhun;
         }
      }
      elsif ($robj->{type} eq 'addCircle') { #Circle
         &parseColor($robj);
         &parsePos($robj);
         &parseCircle($robj) ;
         push @$rPhun, $robj;
         if (exists $robj->{geomID} ){
            $RevHash{ $robj->{geomID}} =  $#$rPhun;
         } else {
            $RevHash{ $_} =  $#$rPhun;
         }
      }
      elsif ($robj->{type} eq 'addPlane') { #
         &parseColor($robj);
         &parsePos($robj);
         &parsePlane($robj) ;
         push @$rPhun, $robj;
         if (exists $robj->{geomID} ){
            $RevHash{ $robj->{geomID}} =  $#$rPhun;
         } else {
            $RevHash{ $_} =  $#$rPhun;
         }
      }
      elsif ($robj->{type} eq 'addSpring') {
         &parseColor($robj);
         &parseSpring($robj) ;
         push @$rPhun, $robj;
      }      
      elsif ($robj->{type} eq 'addHinge') {
         &parseColor($robj);
         &parseHinge($robj) ;
         push @$rPhun, $robj;
      } 
      elsif ($robj->{type} eq 'addFixjoint') {
         &parseColor($robj);
         &parseFixjoint($robj) ;
         push @$rPhun, $robj;
      } 
      elsif ($robj->{type} eq 'addPen') {
         &parseColor($robj);
         &parsePen($robj) ;
         push @$rPhun, $robj;
      } 
      elsif ($robj->{type} eq 'addWater') {
         &parseWater($robj);
         push @$rPhun, $robj;
      }
   }
}

# Parse color data
# INPUT:
#   obj ... a phun object
sub parseColor {
   my $obj = $_[0];
   my ( $color ) = ( $obj->{color} =~ /\[([^][]+)\]/g );
   my ($r, $g, $b, $a) = split(/,/, $color);
   
   $obj->{color} = "#" . sprintf("%02x",$r*255) . sprintf("%02x",$g*255) . sprintf("%02x",$b*255);
   $obj->{stroke} = '#000000';   # default
   $obj->{'stroke-width'} = 1;   # default
   $obj->{'fill-opacity'} = $a;

   # backward compatibility
   unless ( exists $obj->{collideSet}) {
      unless ( exists $obj->{collide} ) { # any of collide option is not support
         $obj->{collideSet} = 1;
      } else {               # collide option is support
         $obj->{collideSet} = ( $obj->{collide} eq 'true' ) ? 1 : 0; # similar to BWC of Phun
      } 
   }
   
   unless ( exists $obj->{collideWater} ) {
      $obj->{collideWater} = 'true';
      $obj->{'stroke-dasharray'} = 'none';
   }
   
   $obj->{collideSet} += 32 while ( $obj->{collideSet}  < 0 );
   if ( $obj->{collideSet} == 0 ) {
      $obj->{stroke} = 'none';
   } else {
      $obj->{'stroke-width'} = 1;
   }
   
   if ( $obj->{collideWater} eq 'true' ) {
      $obj->{'stroke-dasharray'} = 'none';
   } else {
      $obj->{stroke} = '#000000';
      $obj->{'stroke-width'} = max $obj->{'stroke-width'}, 0.5;
      $obj->{'stroke-dasharray'} = 12;
   }
}

# Parse position data
# INPUT:
#   obj ... a phun object
sub parsePos {
   my $obj = $_[0];
   my ( $pos ) = ( $obj->{pos} =~ /\[([^][]+)\]/g );
   my ($x, $y) = split(/,/, $pos);
   $obj->{position} = [ $x, $y ];
}

# Parse vecs data
# INPUT:
#   obj ... a phun object
sub parseVecs {
   my $obj = $_[0];
   my @vecslist = ( $obj->{vecs} =~ /\[([^][]+)\]/g );
   my (@x, @y);
   my $theta = $obj->{angle};
   foreach (@vecslist) {
      my ($x, $y) = split(/,/, $_);
      my ($xp, $yp);
      $xp = $x*cos($theta) - $y*sin($theta);
      $yp = $x*sin($theta) + $y*cos($theta);
      $x = $xp + $obj->{position}[0];
      $y = $yp + $obj->{position}[1];
      $x =  ( $x - $XOFFSET ) / $SCALE;
      $y = -( $y - $YOFFSET ) / $SCALE;
      push @x, $x;
      push @y, $y;
   }
   $obj->{x} = \@x;
   $obj->{y} = \@y;
}

# Parse Box data
# INPUT:
#   obj ... a phun object
sub parseBox {
   my $obj = $_[0];
   my $rotate_angle = $obj->{angle};    #is not equal to theta
   my $x = $obj->{position}[0] - $XOFFSET;
   my $y = $obj->{position}[1] - $YOFFSET;
   my $r = sqrt($x**2 + $y**2);    #r for polar coordinates 
   my $theta = atan2($y, $x);      #theta for polar coordinates 
   my ( $size ) = ( $obj->{size} =~ /\[([^][]+)\]/g );
   ($obj->{width}, $obj->{height}) = split(/,/, $size);
   $obj->{x} =  ($r*cos($theta - $rotate_angle) - $obj->{width} / 2 ) / $SCALE; #prepare for the matrix-form of SVG format
   $obj->{y} = -($r*sin($theta - $rotate_angle) + $obj->{height} / 2 ) / $SCALE; #
   $obj->{width} /= $SCALE;
   $obj->{height} /= $SCALE;
}

# Parse circle data
# INPUT:
#   obj ... a phun object
sub parseCircle {
   my $obj = $_[0];
   $obj->{cx} =  ($obj->{position}[0] - $XOFFSET ) / $SCALE;
   $obj->{cy} = -($obj->{position}[1] - $YOFFSET ) / $SCALE;
   $obj->{r} = $obj->{radius} / $SCALE;
}

# INPUT:
#   obj ... a phun object
sub parsePlane {
   my $obj = $_[0];
   my $theta = $obj->{angle};   # rotation
   my $x1 = $obj->{position}[0] - sin($theta); # end points
   my $y1 = $obj->{position}[1] + cos($theta);
   my $x2 = $obj->{position}[0] + sin($theta);
   my $y2 = $obj->{position}[1] - cos($theta);
   $obj->{x1} =  ( $x1 - $XOFFSET ) / $SCALE;
   $obj->{y1} = -( $y1 - $YOFFSET ) / $SCALE;
   $obj->{x2} =  ( $x2 - $XOFFSET ) / $SCALE;
   $obj->{y2} = -( $y2 - $YOFFSET ) / $SCALE;
}

# Parse spring data
# INPUT:
#   obj ... a phun object
sub parseSpring {
   my $obj = $_[0];
   my ($x0, $y0, $x1, $y1);

   my ( $geom0pos ) = ( $obj->{geom0pos} =~ /\[([^][]+)\]/g );
   ($x0, $y0) = split( /,/, $geom0pos );
   if( $obj->{geom0} == 0 ) {
      $obj->{geom0pos} = ($x0 - ($CAMERA_X - (@$RESOLUTION[0] / $ZOOM / 2))) . ", " .
                ($y0 - ($CAMERA_Y + (@$RESOLUTION[1] / $ZOOM / 2)));
   } else {
      my $obj0 = $Phun[ $RevHash{ $obj->{geom0} } ];
      my $xp = $x0;
      my $yp = $y0;
      my $theta = $obj0->{angle};
      $x0 = $xp*cos($theta) - $yp*sin($theta) + $obj0->{position}[0];
      $y0 = $xp*sin($theta) + $yp*cos($theta) + $obj0->{position}[1];
   }
   my ( $geom1pos ) = ( $obj->{geom1pos} =~ /\[([^][]+)\]/g );
   ($x1, $y1) = split( /,/, $geom1pos );
   if( $obj->{geom1} == 0 ) {
      $obj->{geom1pos} = ($x1 - ($CAMERA_X - (@$RESOLUTION[0] / $ZOOM / 2))) . ", " .
                ($y1 - ($CAMERA_Y + (@$RESOLUTION[1] / $ZOOM / 2)));
   } else {
      my $obj1 = $Phun[ $RevHash{ $obj->{geom1} } ];
      my $xp = $x1;
      my $yp = $y1;
      my $theta = $obj1->{angle};
      $x1 = $xp*cos($theta) - $yp*sin($theta) + $obj1->{position}[0];
      $y1 = $xp*sin($theta) + $yp*cos($theta) + $obj1->{position}[1];
   }
   $obj->{x1} =   ( $x0 - $XOFFSET ) / $SCALE;
   $obj->{y1} =  -( $y0 - $YOFFSET ) / $SCALE;
   $obj->{x2} =   ( $x1 - $XOFFSET ) / $SCALE;
   $obj->{y2} =  -( $y1 - $YOFFSET ) / $SCALE;
   $obj->{size} = $obj->{size} / $SCALE / $PerPoint;
}

# Parse hinge data
# INPUT:
#   obj ... a phun object
sub parseHinge {
   my $obj = $_[0];
   my ($x0, $y0, $x1, $y1);
   
   my ( $geom0pos ) = ( $obj->{geom0pos} =~ /\[([^][]+)\]/g );
   ($x0, $y0) = split( /,/, $geom0pos );
   if( $obj->{geom0} == 0 ) {
      $obj->{geom0pos} = ($x0 - ($CAMERA_X - (@$RESOLUTION[0] / $ZOOM / 2))) . ", " .
                ($y0 - ($CAMERA_Y + (@$RESOLUTION[1] / $ZOOM / 2)));
   } else  {
      my $obj0 = $Phun[ $RevHash{ $obj->{geom0} } ];
      my $xp = $x0;
      my $yp = $y0;
      my $theta = $obj0->{angle};
      $x0 = $xp*cos($theta) - $yp*sin($theta) + $obj0->{position}[0];
      $y0 = $xp*sin($theta) + $yp*cos($theta) + $obj0->{position}[1];
   }
   my ( $geom1pos ) = ( $obj->{geom1pos} =~ /\[([^][]+)\]/g );
   ($x1, $y1) = split( /,/, $geom1pos );
   if( $obj->{geom1} == 0 ) {
      $obj->{geom1pos} = ($x1 - ($CAMERA_X - (@$RESOLUTION[0] / $ZOOM / 2))) . ", " .
                ($y1 - ($CAMERA_Y + (@$RESOLUTION[1] / $ZOOM / 2)));
   } else {
      my $obj1 = $Phun[ $RevHash{ $obj->{geom1} } ];
      my $xp = $x1;
      my $yp = $y1;
      my $theta = $obj1->{angle};
      $x1 = $xp*cos($theta) - $yp*sin($theta) + $obj1->{position}[0];
      $y1 = $xp*sin($theta) + $yp*cos($theta) + $obj1->{position}[1];
   }
   $obj->{x1} =   ( $x0 - $XOFFSET ) / $SCALE;
   $obj->{y1} =  -( $y0 - $YOFFSET ) / $SCALE;
   $obj->{x2} =   ( $x1 - $XOFFSET ) / $SCALE;
   $obj->{y2} =  -( $y1 - $YOFFSET ) / $SCALE;
   $obj->{cx} = ($obj->{x1}+$obj->{x2})/2.0;
   $obj->{cy} = ($obj->{y1}+$obj->{y2})/2.0;
   $obj->{r} = $obj->{size} / 2.0 / $SCALE; # size of hinge is diamiter
}

# Parse Fixate data
# INPUT:
#   obj ... a phun object
sub parseFixjoint {
   my $obj = $_[0];
   my ($x0, $y0, $x1, $y1);
   my ( $geom0pos ) = ( $obj->{geom0pos} =~ /\[([^][]+)\]/g );
   ($x0, $y0) = split( /,/, $geom0pos );
   if( $obj->{geom0} == 0 ) {
      $obj->{geom0pos} = ($x0 - ($CAMERA_X - (@$RESOLUTION[0] / $ZOOM / 2))) . ", " .
                ($y0 - ($CAMERA_Y + (@$RESOLUTION[1] / $ZOOM / 2)));
   } else {
      my $obj0 = $Phun[ $RevHash{ $obj->{geom0} } ];
      my $xp = $x0;
      my $yp = $y0;
      my $theta = $obj0->{angle};
      $x0 = $xp*cos($theta) - $yp*sin($theta) + $obj0->{position}[0];
      $y0 = $xp*sin($theta) + $yp*cos($theta) + $obj0->{position}[1];
   }
   my ( $geom1pos ) = ( $obj->{geom1pos} =~ /\[([^][]+)\]/g );
   ($x1, $y1) = split( /,/, $geom1pos );
   if( $obj->{geom1} == 0 ) {
      $obj->{geom1pos} = ($x1 - ($CAMERA_X - (@$RESOLUTION[0] / $ZOOM / 2))) . ", " .
                ($y1 - ($CAMERA_Y + (@$RESOLUTION[1] / $ZOOM / 2)));
   } else {
      my $obj1 = $Phun[ $RevHash{ $obj->{geom1} } ];
      my $xp = $x1;
      my $yp = $y1;
      my $theta = $obj1->{angle};
      $x1 = $xp*cos($theta) - $yp*sin($theta) + $obj1->{position}[0];
      $y1 = $xp*sin($theta) + $yp*cos($theta) + $obj1->{position}[1];
   }
   $obj->{x1} =   ( $x0 - $XOFFSET ) / $SCALE;
   $obj->{y1} =  -( $y0 - $YOFFSET ) / $SCALE;
   $obj->{x2} =   ( $x1 - $XOFFSET ) / $SCALE;
   $obj->{y2} =  -( $y1 - $YOFFSET ) / $SCALE;
   $obj->{x} = ($obj->{x1}+$obj->{x2})/2.0;
   $obj->{y} = ($obj->{y1}+$obj->{y2})/2.0;
   $obj->{size} = $obj->{size} / 2.0 / $SCALE; # size of Fixate is diamiter
}

# Parse Pen data
# INPUT:
#   obj ... a phun object
sub parsePen {
   my $obj = $_[0];
   my ($x, $y);
   
   my ( $relPoint ) = ( $obj->{relPoint} =~ /\[([^][]+)\]/g );
   ($x, $y) = split( /,/, $relPoint );
   unless ( $obj->{geom} == 0 ) {
      my $obj1 = $Phun[ $RevHash{ $obj->{geom} } ];
      my $xp = $x;
      my $yp = $y;
      my $theta = $obj1->{angle};
      $x = $xp*cos($theta) - $yp*sin($theta) + $obj1->{position}[0];
      $y = $xp*sin($theta) + $yp*cos($theta) + $obj1->{position}[1];
   }
   
   $obj->{cx} = ( $x - $XOFFSET ) / $SCALE;
   $obj->{cy} = -( $y - $YOFFSET ) / $SCALE;
   $obj->{r} = (exists $obj->{size} ? $obj->{size} : 0.1) / 2.0 / $SCALE; # size of Pen is diamiter
}

# Parse Water data
# INPUT:
#   obj ... a phun object
sub parseWater {
   my $obj = $_[0];
   my @vecslist = ( $obj->{vecs} =~ /\[([^][]+)\]/g );
   my (@x, @y);
   foreach (@vecslist) {
      my ($x, $y) = split(/,/, $_);
      $x =  ( $x - $XOFFSET ) / $SCALE;
      $y = -( $y - $YOFFSET ) / $SCALE;
      push @x, $x;
      push @y, $y;
   }
   $obj->{x} = \@x;
   $obj->{y} = \@y;
}

# sort Phun data according to $Phun[ #obj ]{type}.
# INPUT: 
#   reference of Phun data set
sub sortPhun { 
   my $phun = $_[0];
   @$phun = sort {$a->{zDepth} <=> $b->{zDepth}} @$phun; #zDepthの順にソート
   my @ordered;
      push @ordered, $_ foreach ( @$phun );
   $phun = \@ordered;
}


# Define group so as to %group{bodyname} = [id1, id2...]  and $Phun[id]{g} = bodyname. 
# If detouched bodies are in the same group, 
# they are converted to be separated goups body_1, body_2, ...
#
# INPUT:
#   phun .... reference to the phun dataset
# OUTPU:
#   group ... reference to %Group
sub defineGroup {
   my ( $phun, $group ) = @_;
   
   my %seen;
   foreach (0 .. $#$phun) {
      my $obj = $$phun[$_];
      next unless ($obj->{type} eq 'addCircle' || $obj->{type} eq 'addBox'
                                 || $obj->{type} eq 'addPolygon' || $obj->{type} eq 'addPlane');
      $seen{$obj->{body}}++ if exists $obj->{body};
   }
   
   my %subscript;
   foreach (0 .. $#$phun) {
      my $obj = $$phun[$_];
      next unless ($obj->{type} eq 'addCircle' || $obj->{type} eq 'addBox'
                                 || $obj->{type} eq 'addPolygon' || $obj->{type} eq 'addPlane');
      my $body;
      (exists $obj->{body}) ? ($body = $obj->{body}) : next;
      
      next if ($seen{$body} == 1 && $body != 0 );
      my $bodyname;
      if ( $_ == 0 ) {
         $bodyname = $body;
      } elsif ( exists $$phun[$_-1]{body} && $body == $$phun[$_-1]{body} ) { # follow the previous object
         $bodyname = $$phun[$_-1]{g};
      } else {                    # newly defined
         $subscript{ $body }++;
         $bodyname = $body . "_" . $subscript{$body} . "_";
      }
      push @{ $group->{$bodyname} }, $_;
      $obj->{g} = $bodyname;
   }
}

# Extend line of plane.
# INPUT:
#   phun .... reference to the phun dataset
sub extendPlane {
   my $phun = $_[0];
   # bounded box
   my ($xmax, $xmin, $ymax, $ymin) = (-1.e10,1.e10,-1.e10,1.e10);
   foreach ( 0 .. $#$phun ) {
      my $obj = $$phun[$_];
      if ($obj->{type} eq 'addPolygon') {
         $xmax = max( $xmax, @{$obj->{x}} );
         $xmin = min( $xmin, @{$obj->{x}} );
         $ymax = max( $ymax, @{$obj->{y}} );
         $ymin = min( $ymin, @{$obj->{y}} );
      } elsif ($obj->{type} eq 'addBox' ) {
         $xmax = max( $xmax, $obj->{x} + $obj->{width} );
         $xmin = min( $xmin, $obj->{x} - $obj->{width} );
         $ymax = max( $ymax, $obj->{y} + $obj->{height} );
         $ymin = min( $ymin, $obj->{y} - $obj->{height} );
      } elsif ($obj->{type} eq 'addCircle' || $obj->{type} eq 'addHinge' || $obj->{type} eq 'addPen') {
         $xmax = max( $xmax, $obj->{cx} + $obj->{r} );
         $xmin = min( $xmin, $obj->{cx} - $obj->{r} );
         $ymax = max( $ymax, $obj->{cy} + $obj->{r} );
         $ymin = min( $ymin, $obj->{cy} - $obj->{r} );
      } elsif ($obj->{type} eq 'addSpring') {
         $xmax = max( $xmax, $obj->{x1}, $obj->{x2} );
         $xmin = min( $xmin, $obj->{x1}, $obj->{x2} );
         $ymax = max( $ymax, $obj->{y1}, $obj->{y2} );
         $ymin = min( $ymin, $obj->{y1}, $obj->{y2} );
      }
   }
   # redefine plane
   my $dx = $xmax - $xmin;
   my $x0 = ($xmax + $xmin)/2;
   my $dy = $ymax - $ymin;
   my $y0 = ($ymax + $ymin)/2;
   $xmin = $x0 - $dx * $PLANELENGTHFACTOR;
   $xmax = $x0 + $dx * $PLANELENGTHFACTOR;
   $ymin = $y0 - $dy * $PLANELENGTHFACTOR;
   $ymax = $y0 + $dy * $PLANELENGTHFACTOR;
   foreach ( 0 .. $#$phun ) {
      my $obj = $$phun[$_];
      my ($xp, $xq, $yp, $yq);
      next unless ($obj->{type} eq 'addPlane');
      if ( abs($obj->{x2} - $obj->{x1}) > abs($obj->{y2} - $obj->{y1} ) ) { # horizontal crop
         if ( $obj->{x1} > $obj->{x2} ) {
            $xp = $xmax;
            $xq = $xmin;
         } else {
            $xp = $xmin;
            $xq = $xmax;
         }
         $obj->{y1} = ($obj->{y1} - $obj->{y2}) / ($obj->{x1} - $obj->{x2}) *($xp - $obj->{x2}) + $obj->{y2};
         $obj->{x1} = $xp;
         $obj->{y2} = ($obj->{y2} - $obj->{y1}) / ($obj->{x2} - $obj->{x1}) *($xq - $obj->{x1}) + $obj->{y1};
         $obj->{x2} = $xq;
      } else {      # vertical crop
         if ( $obj->{y1} > $obj->{y2} ) {
            $yp = $ymax;
            $yq = $ymin;
         } else {
            $yp = $ymin;
            $yq = $ymax;
         }
         $obj->{x1} = ($obj->{x1} - $obj->{x2}) / ($obj->{y1} - $obj->{y2}) *($yp - $obj->{y2}) + $obj->{x2};
         $obj->{y1} = $yp;
         $obj->{x2} = ($obj->{x2} - $obj->{x1}) / ($obj->{y2} - $obj->{y1}) *($yq - $obj->{y1}) + $obj->{x1};
         $obj->{y2} = $yq;
      }
   }
}


# Creat svg tags
# INPUT:
#   phun ..... reference to the phun dataset (@Phun)
#   group  ... reference to group data (%Group)
# OUTPUT:
#   svg ...... reference to svg dataset
sub Tags {
   my ( $svg, $phun, $group) = @_;
   my %gr;
   my $thisgr;
   foreach my $obj ( @$phun ) {
      my $bodyname = $obj->{g};
      if ( defined $bodyname && exists $group->{$bodyname} && !exists $gr{ $bodyname }) {
         $gr{ $bodyname } = $svg->group(
         id => "body:$bodyname",
         );
      }
      
      $thisgr = ( defined $bodyname && exists $gr{$bodyname} ) ? $gr{$bodyname} : $svg;
      
      if ( $obj->{type} eq 'addPolygon' ) {
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         my $options = &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID
            collideSet collideWater friction geomID heteroCollide restitution
            body angle airFrictionMult controllerAcc controllerInvertX controllerInvertY controllerReverseXY
            density forceController ));
         my $points = $thisgr->get_path (
            x => $obj->{x},
            y => $obj->{y},
            -type => 'polygon',
         );
         $thisgr->polygon (
            %$points,
            'fill' => $obj->{color},
            'stroke' => $obj->{stroke},
            #'stroke-width' => $obj->{'stroke-width'},
            'stroke-dasharray' => $obj->{'stroke-dasharray'},
            'fill-opacity' => $obj->{'fill-opacity'},
            id => $options,
            );
      } elsif ( $obj->{type} eq 'addBox' ) {
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         my $options = &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID
            collideSet collideWater friction geomID heteroCollide restitution
            body angle airFrictionMult controllerAcc controllerInvertX controllerInvertY controllerReverseXY
            density forceController ));
         my $theta = $obj->{'angle'};
         $thisgr->rect (
            x => $obj->{x},
            y => $obj->{y},
            width => $obj->{width},
            height => $obj->{height},
            'fill' => $obj->{color},
            'stroke' => $obj->{stroke},
            'stroke-width' => $obj->{'stroke-width'},
            'stroke-dasharray' => $obj->{'stroke-dasharray'},
            'fill-opacity' => $obj->{'fill-opacity'},
            'transform' => 'matrix(' . cos($theta) . ',' . -sin($theta) . ',' . sin($theta) . ',' . cos($theta) . ',0,0)',
            id => $options,
            );
      } elsif ( $obj->{type} eq 'addCircle' ) {
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         my $options = &addtoOptions( $obj, qw( angle buttonDestroy buttonMirror entityID
            collideSet collideWater friction geomID heteroCollide restitution
            body airFrictionMult controllerAcc controllerInvertX controllerInvertY controllerReverseXY
            density forceController ));
         $thisgr->circle(
            cx => $obj->{cx}, 
            cy => $obj->{cy}, 
            r  => $obj->{r},
            'fill' => $obj->{color},
            'stroke' => $obj->{stroke},
            'stroke-width' => $obj->{'stroke-width'},
            'stroke-dasharray' => $obj->{'stroke-dasharray'},
            'fill-opacity' => $obj->{'fill-opacity'},
            id => $options,
         );
      } elsif ( $obj->{type} eq 'addPlane' ) {
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         my $options = &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID
            collideSet collideWater friction geomID heteroCollide restitution));
         $thisgr->line (
            x1 => $obj->{x1},
            y1 => $obj->{y1},
            x2 => $obj->{x2},
            y2 => $obj->{y2},
            'stroke' => $obj->{color},
            'stroke-width' => $obj->{'stroke-width'},
            'stroke-dasharray' => $obj->{'stroke-dasharray'},
            'fill-opacity' => $obj->{'fill-opacity'},
            id => $options,
         );
      } elsif ( $obj->{type} eq 'addSpring' ) {
         next if ($obj->{geom0} == 0 && $obj->{geom1} ==0);
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         $Id{spring} = 0 unless (exists $Id{spring});
         $Id{spring}++;
         my $options = "id:$Id{spring};";
         $options .= &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID
                        size geom0 geom0pos geom1 geom1pos dampingFactor length strengthFactor));
         $thisgr->line (
            x1 => $obj->{x1},
            y1 => $obj->{y1},
            x2 => $obj->{x2},
            y2 => $obj->{y2},
            'stroke-width' => $obj->{size},
            'stroke' => '#000000',
            'fill-opacity' => $obj->{'fill-opacity'},
            id => $options,
         );
      } elsif ( $obj->{type} eq 'addHinge' ) {
         next if ($obj->{geom0} == 0 && $obj->{geom1} ==0);
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         $Id{hinge} = 0 unless (exists $Id{hinge});
         $Id{hinge}++;
         my $options = "id:$Id{hinge};";
         $options .= &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID
                        geom0 geom0pos geom1 geom1pos autoBrake buttonBack buttonBrake buttonForward
                        ccw distanceLimit impulseLimit motor motorSpeed motorTorque));
         $thisgr->circle(
            cx => $obj->{cx}, 
            cy => $obj->{cy}, 
            r  => $obj->{r},
            'stroke' => $obj->{color},
            'fill' => 'none',
            'stroke-opacity' => $obj->{'fill-opacity'},
            id => $options,
         );
      } elsif ( $obj->{type} eq 'addFixjoint' ) {
         next if ($obj->{geom0} == 0 && $obj->{geom1} ==0);
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         $Id{fixate} = 0 unless (exists $Id{fixate});
         $Id{fixate}++;
         my $options = "id:$Id{fixate};";
         $options .= &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID  
                        geom0 geom0pos geom1 geom1pos));
         my @x_ = ($obj->{x} - $obj->{size}, $obj->{x} + $obj->{size}, $obj->{x} + $obj->{size}, $obj->{x} - $obj->{size});
         my @y_ = ($obj->{y} - $obj->{size}, $obj->{y} + $obj->{size}, $obj->{y} - $obj->{size}, $obj->{y} + $obj->{size});
         my $points = $thisgr->get_path (
            x => \@x_,
            y => \@y_,
            -type => 'polygon',
         );
         $thisgr->polygon(
            %$points,
            'fill' => 'none',
            'stroke-opacity' => $obj->{'fill-opacity'},
            'stroke' => $obj->{color},
            'stroke-width' => $obj->{size} / 4,
            'filter' => 'fixjoint',
            id => $options,
         );
      } elsif ( $obj->{type} eq 'addPen' ) {
         next if ($obj->{geom} == 0);
         $obj->{zDepth} = $LASTzDEPTH + 1 unless (exists $obj->{zDepth});
         $LASTzDEPTH = $obj->{zDepth};
         $Id{pen} = 0 unless (exists $Id{pen});
         $Id{pen}++;
         my $options = "id:$Id{pen};";
         $options .= &addtoOptions( $obj, qw( buttonDestroy buttonMirror entityID
                                                  size geom fadeTime relPoint));
         $thisgr->circle(
            cx => $obj->{cx}, 
            cy => $obj->{cy}, 
            r  => $obj->{r},
            'stroke' => $obj->{color},
            'fill' => 'none',
            'stroke-width' => $obj->{r} / 4,
            'stroke-dasharray' => "$obj->{r}" . "," . "$obj->{r}",
            'stroke-opacity' => $obj->{'fill-opacity'},
            id => $options,
         );
      } 
      
      if ( $obj->{type} eq 'addWater' ) {
         $thisgr = $svg->group(
            id => "addWater",
            fill => "blue",
            stroke => "none",
            'fill-opacity' => '0.5',
         );
         foreach ( 0 .. $#{$obj->{x}}){
            $thisgr->circle(
               id => "water:" . $_,
               cx => $obj->{x}[$_],
               cy => $obj->{y}[$_],
               r => '5',
               filter => 'water',
            );
         }
      }
   }
}

# add the options to a svg-id option
# INPUT:
#  obj ........ a reference to an object.
#  options .... a list of keys to be specified.
# RETURN
#  string of svg-id option.
sub addtoOptions {
   my ( $obj, @options ) = @_;
   my $idtag = '';
   foreach my $opt (@options ){
      $idtag .= "$opt:$obj->{$opt};" if (exists $obj->{$opt});
   }
   chop $idtag;
   return $idtag;
}

# execute svg2phun.pl or svg2phun.exe
sub execute_phun2svg {
   my ($exe_filename, $phn_filename) = @_;
   if ($exe_filename =~ /phun2svg2.exe/i) {
      $exe_filename =~ s/phun2svg2.exe/phun2svg.exe/i;
      if (-e $exe_filename){
         print ("Phn-file-version = 1 so that execute $exe_filename $phn_filename.\n");
         system ("$exe_filename $phn_filename");
      } else {
         print "********************************************************************\n" .
               "   Phn-file-version = 1 so that you have to execute phun2svg.exe.\n". 
               "   In advance put phun2svg.exe on the same folder,\n" . 
               "   then, this script executes it automatically.\n" .
               "********************************************************************\n";
         sleep 3;
      }
   } else {
      $exe_filename =~ s/phun2svg2.pl/phun2svg.pl/i;
      if (-e $exe_filename){
         print ("Phn-file-version = 1 so that execute $exe_filename $phn_filename.\n");
         exec ("$exe_filename $phn_filename");
      } else {
         print "********************************************************************\n" .
               "   Phn-file-version = 1 so that you have to execute phun2svg.pl.\n" .
               "   In advance, put phun2svg.pl on the same folder,\n" . 
               "   then, this script executes it automatically.\n" .
               "********************************************************************\n";
      }
   }
   
   exit;
}
