#!/usr/bin/perl
#remove line segments v0.0.1
#scottvr@gmail.com
#
#remove "long" lines from sparse areas in SVGs
#that were created by the Eggbot TSP Art tools.
#it will work on SVGs that were created by other
#means but since it was written for this specific
#purpose I don't do proper SVG handling and just
#work on the "path d=" elements, regurgitating
#the preamble from the eggbot tspart.py script
#
$DEBUG = 0;
my $file = shift(@ARGV);

my $threshold_pct = 1;
# TODO: change from percent of longest edge, to deviation from rest of lengths.

use warnings;
use XML::Parser;
use Image::SVG::Path 'extract_path_info';
use Image::Info qw(image_info dim);

# let's just use the header from eggbot toolkit
my $SVGHEAD = <<EOHEAD;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Created with the Eggbot TSP art toolkit (http://egg-bot.com) -->

<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
     xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
     xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
     xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns:cc="http://creativecommons.org/ns#"
EOHEAD

my $SVGMID = <<EOMID;
  <sodipodi:namedview
            showgrid="false"
            showborder="true"
            inkscape:showpageshadow="false"/>
  <metadata>
    <rdf:RDF>
      <cc:Work rdf:about="">
        <dc:format>image/svg+xml</dc:format>
        <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
        <dc:subject>
          <rdf:Bag>
            <rdf:li>Egg-Bot</rdf:li>
            <rdf:li>Eggbot</rdf:li>
            <rdf:li>TSP</rdf:li>
            <rdf:li>TSP art</rdf:li>
          </rdf:Bag>
        </dc:subject>
        <dc:description>TSP art created with the Eggbot TSP art toolkit (http://egg-bot.com)</dc:description>
      </cc:Work>
    </rdf:RDF>
  </metadata>
EOMID

# TODO: clean this up.. only one of these is needed now
my %L = ( 'l' => 'm', 'L' => 'M', 'm' => 'm', 'M' => 'M', 'z' => 'z', 'Z' => 'Z');

my $info = image_info("$file");
if (my $err = $info->{error}) {
    die "Error obtaining image_info: $err\n";
}
my($w, $h) = dim($info);
($w) = ($w =~ /(\d+)/); # stop at first non-digit.. easy way
($h) = ($h =~ /(\d+)/); # stop at first non-digit.. easy way
my $l = ($w > $h) ? $w : $h;
$l *= 1.0; # don't remember why this was here

print $SVGHEAD;
print "height=\"$h\"\n";
print "width=\"$w\">\n";
print $SVGMID;
my $p = XML::Parser->new (Handlers => {Start => \& start});
$p->parsefile ($file) or die "Error $file: ";
print '</svg>';
sub start
{
    my ($expat, $element, %attr) = @_;
    #foreach $k (keys %attr) {
    #print "$k=\"$attr{$k}\"\n";
    #}
    if($element ne 'path') {
    #    print @_;
    } else {
#    print 'd= "M 0,0 ';
	my $d = $attr{d};
	my @r = extract_path_info ($d, {absolute=>1});
    my $dist = 0;
    my $prev_cmd = "";
    my $prev_point = '';
    my @s;
	for (@r) {
        if ($DEBUG) { print STDERR "\n\rline$_->{svg_key}\n";}
        my $cur_point = $_->{point};
        my $cur_cmd = $_->{svg_key};
        if ($cur_cmd ne $prev_cmd) { $cmd_changed=1; } else { $cmd_changed=0;}
        #if ("$cur_cmd" ne "$prev_cmd") {
        #    print " M @$cur_point " if($cur_cmd =~ /^L$/i);
        #    $last_point_cmdchange = $cur_point;
        #}
	    if ($cur_cmd =~ /^M$/i) {
            pop(@s) if($cur_cmd eq $prev_cmd);
        #print "cp $cur_point\npp $prev_point\nacp",join(',',@$cur_point), " app ",join(',',@$prev_point),"\n";
		    push (@s,"$cur_cmd ".join(',',@{$cur_point})." ");
            $prev_point = $cur_point;
	    } elsif ($cur_cmd =~ /^L$/i) {
        #print "cp $cur_point\npp $prev_point\nacp",join(',',@$cur_point), " app ",join(',',@$prev_point),"\n";
        if ($prev_point) {
            $dist = &dist_between(@$cur_point,@$prev_point);
            if ($DEBUG) { print STDERR "\n\rRET $dist\n";}
        }
        if($dist == 0){ goto NOMOVE; }
        if ($DEBUG) { print STDERR "\n\r",sprintf("%2.2f", $dist/$l*100),"\%\n";}
        if ($DEBUG) { print STDERR "dist = $dist l = $l dist/l=",$dist/$l,"\n";}
        if($dist && (($dist/$l*100) < $threshold_pct)) {
            my $cur_cmd = $cmd_changed ? $cur_cmd : "";
		    push(@s,"$cur_cmd ".join(',',@{$cur_point})." ");
        } else {
            # delete this segment
            $cur_cmd = 'M';
            my $actual_thresh = ($l * $threshold_pct/100);
            print STDERR "$dist IS GREATER THAN THRESH ($actual_thresh), XLATE\n";# if $DEBUG;
		    push(@s,"$cur_cmd ".join(',',@{$cur_point})." ");
            #print "$L{$cur_cmd} ",join(',',@{$cur_point})," ";
            #	we're using absolute coordinates.. just skip don't xlate?
            #	may have to adjust the transition state but luckily i added
            #	the unused prev_cmd business
        }
        }
        NOMOVE:
        $prev_point = $cur_point;
        $prev_cmd = $cur_cmd;
    }
    print '<path style="fill:none;stroke:#000000;stroke-width:1"',
          "\nd=\"",@s,"\" />\n";
 }
}

sub dist_between()  {
    return 0 unless(@_);
    if ($DEBUG) { print  "\n\rGOT: ", join(',',@_),"\n";}
    my ($x1,$y1,$x2,$y2) = (@_);
    return sqrt(($x2 - $x1) ** 2 + ($y2 - $y1) ** 2);
}
