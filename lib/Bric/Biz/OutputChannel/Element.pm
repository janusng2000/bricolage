package Bric::Biz::OutputChannel::Element;
#############################################################################

=head1 NAME

Bric::Biz::OutputChannel::Element - Maps Output Channels to Elements.

=head1 VERSION

$Revision: 1.2.2.1 $

=cut

our $VERSION = (qw$Revision: 1.2.2.1 $ )[-1];

=head1 DATE

$Date: 2003-03-08 20:33:50 $

=head1 SYNOPSIS

  use Bric::Biz::OutputChannel::Element;

  # Constructors.
  my $oce = Bric::Biz::OutputChannel->new($init);
  my $oces_href = Bric::Biz::OutputChannel->href($params);

  # Instance methods.
  my $element_id = $oce->get_element_id;
  $oce->set_element_id($element_id);
  $oce->set_enabled_on;
  $oce->set_enabled_off;
  if ($oce->is_enabled) { } # do stuff.
  $oce->save;

=head1 DESCRIPTION

This subclass of Bric::Biz::OutputChannel manages the relationship between
output channels and elements (Bric::Biz::AssetType objects). It does so by
providing accessors to properties relevant to the relationship, as well as an
C<href()> method to help along the use of a Bric::Util::Coll object.

=cut

##############################################################################
# Dependencies
##############################################################################
# Standard Dependencies
use strict;

##############################################################################
# Programmatic Dependences
use Bric::Util::DBI qw(:all);

use Bric::Util::Fault::Exception::DP;

##############################################################################
# Inheritance
##############################################################################
use base qw(Bric::Biz::OutputChannel);

##############################################################################
# Function and Closure Prototypes
##############################################################################
# None.

##############################################################################
# Constants
##############################################################################
use constant DEBUG => 0;

##############################################################################
# Fields
##############################################################################
# Public Class Fields

##############################################################################
# Private Class Fields
my $SEL_COLS = Bric::Biz::OutputChannel::SEL_COLS() .
  ', eoc.id, eoc.element__id, eoc.enabled';
my @SEL_PROPS = (Bric::Biz::OutputChannel::SEL_PROPS(),
                 qw(_map_id element_id _enabled));
my $SEL_TABLES = Bric::Biz::OutputChannel::SEL_TABLES() .
  ', element__output_channel eoc';
my $SEL_WHERES = Bric::Biz::OutputChannel::SEL_WHERES() .
  ' AND oc.id = eoc.output_channel__id AND eoc.element__id = ?';
my $SEL_ORDER = Bric::Biz::OutputChannel::SEL_ORDER();
my $GRP_ID_IDX = Bric::Biz::OutputChannel::GRP_ID_IDX();

##############################################################################
# Instance Fields
BEGIN {
    Bric::register_fields({ element_id => Bric::FIELD_RDWR,
                            _enabled => Bric::FIELD_NONE,
                            _map_id => Bric::FIELD_NONE });

}

##############################################################################
# Class Methods
##############################################################################

=head1 INTERFACE

This class inherits the majority of its interface from
L<Bric::Biz::OutputChannel|Bric::Biz::OutputChannel>. Only additional methods
are documented here.

=head2 Constructors

=over 4

=item my $oce = Bric::Biz::OutputChannel::Element->new($init);

Constructs a new Bric::Biz::OutputChannel::Element object intialized with the
values in the C<$init> hash reference and returns it. The suported values for
the C<$init> hash reference are the same as those supported by
C<< Bric::Biz::OutputChannel::Element->new >>, with the addition of the
following:

=over 4

=item C<oc_id>

The ID of the output channel object on which the new
Bric::Biz::OutputChannel::Element will be based. The relevant
Bric::Biz::OutputChannel object will be looked up from the database. Note that
all of the C<$init> parameters documented in
L<Bric::Biz::OutputChannel|Bric::Biz::OutputChannel> will be ignored if this
parameter is passed.

=item C<oc>

The output channel object on which the new Bric::Biz::OutputChannel::Element
will be based. Note that all of the C<$init> parameters documented in
L<Bric::Biz::OutputChannel|Bric::Biz::OutputChannel> will be ignored if this
parameter is passed.

=item C<site_id>

Needed only if a C<oc_id> or C<oc> parameter is not given.  If neither of these
parameters exist, this constructor will create a new Output Channel which 
requires a site ID.

=item C<element_id>

The ID of the Bric::Biz::AssetType object to which this output channel is
mapped.

=item C<enabled>

A boolean value indicating whether the output channel will have assets output
to it by default.

=back

B<Throws:>

=over 4

=item *

Unable to connect to database.

=item *

Unable to prepare SQL statement.

=item *

Unable to select column into arrayref.

=item *

Unable to execute SQL statement.

=item *

Unable to bind to columns to statement handle.

=item *

Unable to fetch row from statement handle.

=back

B<Side Effects:> If you pass in an output channel object via the C<oc>
parameter, that output channel object will be converted into a
Bric::Biz::OutputChannel::Element object.

B<Notes:> NONE.

=cut

sub new {
    my ($pkg, $init) = @_;
    my $en = ! exists $init->{enabled} ? 1 : delete $init->{enabled} ? 1 : 0;
    my ($eid, $oc, $ocid) = delete @{$init}{qw(element_id oc oc_id)};
    my $self;
    if ($oc) {
        # Rebless the existing output channel object.
        $self = bless $oc, ref $pkg || $pkg;
    } elsif ($ocid) {
        # Lookup the existing output channel object.
        $self = $pkg->lookup({ id => $ocid });
    } else {
        unless ($init->{site_id}) {
            my $msg = "Without 'oc' or 'oc_id' arguments, you must pass ".
                      "'site_id'";
            die Bric::Util::Fault::Exception::DP->new({msg => $msg});
        }
        # Construct a new output channel object.
        $self = $pkg->SUPER::new($init);
    }
    # Set the necessary properties and return.
    $self->_set([qw(_enabled element_id)], [$en, $eid]);
}

##############################################################################

=item my $oce_href =
Bric::Biz::OutputChannel::Element->href({ element_id => $eid });

Returns a hash reference of Bric::Biz::OutputChannel::Element objects. Each
hash key is a Bric::Biz::OutputChannel::Element ID, and the values are the
corresponding Bric::Biz::OutputChannel::Element objects. Only a single
parameter argument is allowed, C<element_id>. All of the output channels
associated with that element ID will be returned.

B<Throws:>

=over 4

=item *

Unable to connect to database.

=item *

Unable to prepare SQL statement.

=item *

Unable to select column into arrayref.

=item *

Unable to execute SQL statement.

=item *

Unable to bind to columns to statement handle.

=item *

Unable to fetch row from statement handle.

=back

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

sub href {
    my ($pkg, $params) = @_;
    my $class = ref $pkg || $pkg;

    # HACK: Really there's too much going on here getting information from
    # the parent class. Perhaps one day we'll have a SQL factory class to
    # handle all this stuff, but this will have to do for now.
    my $sel = prepare_c(qq{
        SELECT $SEL_COLS
        FROM   $SEL_TABLES
        WHERE  $SEL_WHERES
        ORDER BY $SEL_ORDER
    }, undef, DEBUG);

    execute($sel, $params->{element_id});
    my (@d, %ocs, $grp_ids);
    bind_columns($sel, \@d[0..$#SEL_PROPS]);
    my $last = -1;
    $pkg = ref $pkg || $pkg;
    while (fetch($sel)) {
        if ($d[0] != $last) {
            $last = $d[0];
            # Create a new server type object.
            my $self = $pkg->SUPER::new;
            # Get a reference to the array of group IDs.
            $grp_ids = $d[$GRP_ID_IDX] = [$d[$GRP_ID_IDX]];
            $self->_set(\@SEL_PROPS, \@d);
            $self->_set__dirty; # Disables dirty flag.
            $ocs{$d[0]} = $self;
        } else {
            push @$grp_ids, $d[$GRP_ID_IDX];
        }
    }
    # Return the objects.
    return \%ocs;
}

=back

##############################################################################

=head2 Public Instance Methods

=over 4

=item my $eid = $oce->get_element_id

Returns the ID of the Element definition with which this output channel is
associated.

B<Throws:> NONE.

B<Side Effects:> NONE.

B<Notes:> NONE.

=item $oce = $oce->set_element_id($eid)

Sets the ID of the Element definition with which this output channel is
associated.

B<Throws:> NONE.

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

##############################################################################

=item $oce = $oce->set_enabled_on

Enables this output channel to have assets ouptut to it by default.

B<Throws:> NONE.

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

sub set_enabled_on { $_[0]->_set(['_enabled'], [1]) }

##############################################################################

=item $oce = $oce->set_enabled_off

Sets this output channel to not have assets ouptut to it by default.

B<Throws:> NONE.

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

sub set_enabled_off { $_[0]->_set(['_enabled'], [0]) }

##############################################################################

=item $oce = $oce->is_enabled

Returns true if the this output channel is set to have assets output to it by
default, and false if it is not.

B<Throws:> NONE.

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

sub is_enabled { $_[0]->_get('_enabled') ? $_[0] : undef }

##############################################################################

=item $oce = $oce->remove

Marks this output channel-element association to be removed. Call the
C<save()> method to remove the mapping from the database.

B<Throws:> NONE.

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

sub remove { $_[0]->_set(['_del'], [1]) }

##############################################################################

=item $oce = $oce->save

Saves the output channel.

B<Throws:>

=over 4

=item *

Bric::_get() - Problems retrieving fields.

=item *

Unable to connect to database.

=item *

Unable to prepare SQL statement.

=item *

Unable to execute SQL statement.

=item *

Unable to select row.

=item *

Incorrect number of args to _set.

=item *

Bric::_set() - Problems setting fields.

=back

B<Side Effects:> NONE.

B<Notes:> NONE.

=cut

sub save {
    my $self = shift;
    return $self unless $self->_get__dirty;
    # Save the base class' properties.
    $self->SUPER::save;
    # Save the enabled property.
    my ($ocid, $eid, $map_id, $en, $del) =
      $self->_get(qw(id element_id _map_id _enabled _del));
    if ($del and $map_id) {
        # Delete it.
        my $del = prepare_c(qq{
            DELETE FROM element__output_channel
            WHERE  id = ?
        });
        execute($del, $map_id);
        $self->_set([qw(_map_id _del)], []);

    } elsif ($map_id) {
        # Update the existing value.
        my $upd = prepare_c(qq{
            UPDATE element__output_channel
            SET    output_channel__id = ?,
                   element__id = ?,
                   enabled = ?,
                   active = 1
            WHERE  id = ?
        });
        execute($upd, $ocid, $eid, $en, $map_id);

    } else {
        # Insert a new record.
        my $nextval = next_key('element__output_channel');
        my $ins = prepare_c(qq{
            INSERT INTO element__output_channel
                        (id, element__id, output_channel__id, enabled, active)
            VALUES ($nextval, ?, ?, ?, 1)
        });
        execute($ins, $eid, $ocid, $en);
        $self->_set(['_map_id'], [last_key('element__output_channel')]);
    }
    return $self;
}

1;
__END__

=back

=head1 NOTES

NONE.

=head1 AUTHOR

David Wheeler <david@wheeler.net>

=head1 SEE ALSO

L<Bric::Biz::OutputChannel|Bric::Biz::OutputChannel>,
L<Bric::Biz::AssetType|Bric::Biz::AssetType>,

=cut
