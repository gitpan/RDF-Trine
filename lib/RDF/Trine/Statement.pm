# RDF::Trine::Statement
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Statement - Algebra class for Triple patterns

=cut

package RDF::Trine::Statement;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= 0.108;
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $s, $p, $o )>

Returns a new Triple structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	Carp::confess "Triple constructor must have three node arguments" unless (scalar(@nodes) == 3);
	my @names	= qw(subject predicate object);
	foreach my $i (0 .. 2) {
		unless (defined($nodes[ $i ])) {
			$nodes[ $i ]	= RDF::Trine::Node::Variable->new($names[ $i ]);
		}
	}
	
	return bless( [ @nodes ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->nodes);
}

=item C<< nodes >>

Returns the subject, predicate and object of the triple pattern.

=cut

sub nodes {
	my $self	= shift;
	my $s		= $self->subject;
	my $p		= $self->predicate;
	my $o		= $self->object;
	return ($s, $p, $o);
}

=item C<< subject >>

Returns the subject node of the triple pattern.

=cut

sub subject {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< predicate >>

Returns the predicate node of the triple pattern.

=cut

sub predicate {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< object >>

Returns the object node of the triple pattern.

=cut

sub object {
	my $self	= shift;
	if (@_) {
		$self->[2]	= shift;
	}
	return $self->[2];
}

=item C<< as_string >>

Returns the statement in a string form.

=cut

sub as_string {
	my $self	= shift;
	return $self->sse;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	return sprintf(
		'(triple %s %s %s)',
		$self->subject->sse( $context ),
		$self->predicate->sse( $context ),
		$self->object->sse( $context ),
	);
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'TRIPLE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq(map { $_->name } grep { blessed($_) and $_->isa('RDF::Trine::Node::Variable') } $self->nodes);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->referenced_variables;
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( $self->nodes );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my @nodes	= $self->nodes;
	foreach my $i (0 .. 2) {
		my $n	= $nodes[ $i ];
		if ($n->isa('RDF::Trine::Node::Variable')) {
			my $name	= $n->name;
			if (my $value = $bound->{ $name }) {
				$nodes[ $i ]	= $value;
			}
		}
	}
	return $class->new( @nodes );
}

=item C<< subsumes ( $statement ) >>

Returns true if this statement will subsume the $statement when matched against
a triple store.

=cut

sub subsumes {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $self->nodes;
	my @match	= $st->nodes;
	
	my %bind;
	my $l		= Log::Log4perl->get_logger("rdf.trine.statement");
	foreach my $i (0..2) {
		my $m	= $match[ $i ];
		if ($nodes[$i]->isa('RDF::Trine::Node::Variable')) {
			my $name	= $nodes[$i]->name;
			if (exists( $bind{ $name } )) {
				$l->debug("variable $name has already been bound");
				if (not $bind{ $name }->equal( $m )) {
					$l->debug("-> and " . $bind{$name}->sse . " does not equal " . $m->sse);
					return 0;
				}
			} else {
				$bind{ $name }	= $m;
			}
		} else {
			return 0 unless ($nodes[$i]->equal( $m ));
		}
	}
	return 1;
}


=item C<< from_redland ( $statement ) >>

Given a RDF::Redland::Statement object, returns a perl-native
RDF::Trine::Statement object.

=cut

sub from_redland {
	my $self	= shift;
	my $rstmt	= shift;
	my $rs		= $rstmt->subject;
	my $rp		= $rstmt->predicate;
	my $ro		= $rstmt->object;
	
	my $cast	= sub {
		my $node	= shift;
		my $type	= $node->type;
		if ($type == $RDF::Redland::Node::Type_Resource) {
			return RDF::Trine::Node::Resource->new( $node->uri->as_string );
		} elsif ($type == $RDF::Redland::Node::Type_Blank) {
			return RDF::Trine::Node::Blank->new( $node->blank_identifier );
		} elsif ($type == $RDF::Redland::Node::Type_Literal) {
			my $lang	= $node->literal_value_language;
			my $dturi	= $node->literal_datatype;
			my $dt		= ($dturi)
						? $dturi->as_string
						: undef;
			return RDF::Trine::Node::Literal->new( $node->literal_value, $lang, $dt );
		} else {
			die;
		}
	};
	
	my @nodes;
	foreach my $n ($rs, $rp, $ro) {
		push(@nodes, $cast->( $n ));
	}
	my $st	= $self->new( @nodes );
	return $st;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
