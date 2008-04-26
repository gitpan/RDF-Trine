# RDF::Trine::Iterator::Bindings::Materialized
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Bindings::Materialized - Materialized bindings class.

=head1 SYNOPSIS

    use RDF::Trine::Iterator;
    
    my $iterator = RDF::Trine::Iterator::Bindings::Materialized->new( \@data, \@names );
    while (my $row = $iterator->next) {
    	my @vars	= keys %$row;
    	# do something with @vars
    }

    my $iterator = RDF::Trine::Iterator::Bindings->new( \&code, \@names );
    my $miter = $iterator->materialize;
    while (my $row = $miter->next) {
    	my @vars	= keys %$row;
    	# do something with @vars
    }
    $miter->reset; # start the iteration again
    while (my $row = $miter->next) {
        # ...
    }

=head1 METHODS

=over 4

=cut

package RDF::Trine::Iterator::Bindings::Materialized;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use base qw(RDF::Trine::Iterator::Bindings);

use Data::Dumper;
use Scalar::Util qw(blessed reftype);

our ($VERSION, $debug);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$VERSION	= 0.107;
}

=item C<< new ( \@results, \@names, %args ) >>

Returns a new materialized bindings interator. Results must be a reference to an
array containing individual results.

=cut

sub new {
	my $class	= shift;
	my $data	= shift || [];
	my $names	= shift || [];
	Carp::confess unless (scalar(@_) % 2 == 0);
	my %args	= @_;
	
	if (reftype($data) eq 'CODE') {
		my @rows;
		while (my $row = $data->()) {
			push(@rows, $row);
		}
		$data	= \@rows;
	}
	
	Carp::confess "not an ARRAY: " . Dumper($data) unless (reftype($data) eq 'ARRAY');
	
	my $type	= 'bindings';
	my $index	= 0;
	my $stream	= sub {
		my $data	= $data->[ $index++ ];
		unless (defined($data)) {
			$index	= 0;
		}
		return $data;
	};
	my $self	= $class->SUPER::new( $stream, $names, %args );
	$self->{_data}	= $data;
	$self->{_index}	= \$index;
	
	return $self;
}

=item C<< reset >>

Returns the iterator to its starting position.

=cut

sub reset {
	my $self	= shift;
	${ $self->{_index} }	= 0;
}

=item C<< next >>

Returns the next item in the iterator.

=cut

sub next {
	my $self	= shift;
	my $data	= $self->SUPER::next;
	unless (defined($data)) {
		$self->{_finished}	= 0;
	}
	return $data;
}

=item C<< length >>

Returns the number of elements in the iterator.

=cut

sub length {
	my $self	= shift;
	return scalar(@{ $self->{ _data } });
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


