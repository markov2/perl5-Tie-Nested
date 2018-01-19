# This code is part of distribution Tie::Nested.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Tie::Nested;

use warnings;
use strict;

use Log::Report 'tie-nested', syntax => 'SHORT';
use Data::Dumper;

=chapter NAME
Tie::Nested - multiple levels of nested tied HASHes and ARRAYs

=chapter SYNOPSIS

  tie my(%d), 'Tie::Nested', recurse => 'Hash::Case::Lower';
  $d{FOO} = 'BAR';
  print $d{Foo};   # BAR
  print $d{fOo};   # BAR
  print keys %$d;  # foo

  $d{FOO}{BAR} = 42;
  print Data::Dumper::Dumper \%d;   # {foo => {bar => 42}};

  $d{nEw} = +{with}{NestEd}{asSIgn => 3}; # works!

  tie my(%e), 'Tie::Nested'
     , nestings => ['Hash::Case::Lower', 'Hash::Case::Upper'];
  $e{FOO}{bar}{Tic} = 42;
  print Data::Dumper::Dumper \%e;   # {foo => {BAR => {Tic => 42}}};

=chapter DESCRIPTION

Tie a data-structure automatically.  On the top level, we specify
for each of the sub-levels how they have to be tied. But after
that, we do not need to care.

For instance, we have read/are reading a directory structure
for a case-insensitive file-system.

=chapter METHODS

=section constructors

=tie HASH, 'Tie::Nested', [DATA], OPTIONS

Tie to a new HASH. The optional DATA contains the initial contents
for the HASH.

Either the C<recurse> or the C<nesting> option is required. For examples,
see the SYNOPSIS.

=option  recurse TIECLASS
=default recurse C<undef>
The TIECLASS implements a tie. Each of the nested structures will tie to
this same TIECLASS.

=option nesting  ARRAY-of-TIECLASS
=default nesting []
Each of the TIECLASSes implements a tie. For the first level, the first
TIECLASS is used. For the second the next, and so forth until you run
out of classes. Then, we proceed with

=cut

sub TIEHASH(@)
{   my $class = shift;
    my $add   = @_ % 2 ? shift : {};
    my $self  = (bless {}, $class)->init({@_} );
    my @a     = %$add;
    tie %$add, $self->{mine};
    $self->{data} = $add;
    $self->STORE(shift @a, shift @a) while @a;
    $self;
}

=tie ARRAY, 'Tie::Nested', [DATA], OPTIONS
See tie on HASH. You can use ARRAYs as well!  All examples are with
HASHes, but you are not limited to HASHes!
=cut

sub TIEARRAY(@)
{   my $class = shift;
    my $add   = @_ % 2 ? shift : [];
    $add = [$add] if ref $add ne 'ARRAY';
    my $self  = (bless {}, $class)->init( {@_} );
    tie @$add, $self->{mine};
    $self->{data} = $add;
    $self;
}

sub init($)
{   my ($self, $args) = @_;

    my ($mine, @nest_opts);
    if(my $r = $args->{recurse})
    {   $r = [ $r ] if ref $r ne 'ARRAY';
        $mine = $r->[0];
        @nest_opts  = (recurse => $r);
    }
    elsif(my $n = $args->{nestings})
    {   ($mine, my @nest) = ref $n eq 'ARRAY' ? @$n : $n;
        @nest_opts  = (nestings => \@nest) if @nest;
    }
    else
    {   error __x"tie needs either 'recurse' or 'nestings' parameter";
    }

    defined $mine
	or error __x"requires a package name for the tie on the data";

    $self->{mine} = $mine;
    $self->{nest} = \@nest_opts if @nest_opts;
    $self;
}

sub STORE($$$)
{   my ($self, $k, $v) = @_;
    my $t = $self->{mine};
    my $d = $self->{data} ||= $t->($k, $v);

    if(my $nest = $self->{nest})
    {
	if(ref $v eq 'HASH' && $nest->[1][0]->can('TIEHASH'))
	{   tie %$v, ref $self, {%$v}, @$nest;
            return $d->{$k} = $v;
        }
        elsif(ref $v eq 'ARRAY' && $nest->[1][0]->can('TIEARRAY'))
        {   tie @$v, ref $self, [@$v], @$nest;
            return $d->{$k} = $v;
	}
    }

    (tied %$d)->STORE($k, $v);
}

my $end;
END { $end++ }

our $AUTOLOAD;
sub AUTOLOAD(@)
{   return if $end;
    $AUTOLOAD =~ s/.*\:\://;
    my $d     = shift->{data};
    my $obj   = tied %$d;
    return if $AUTOLOAD eq 'DESTROY' && ! $obj->can('DESTROY');
    $obj->$AUTOLOAD(@_);
}

1;
