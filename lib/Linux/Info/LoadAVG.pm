package Linux::Info::LoadAVG;
use strict;
use warnings;
use Carp qw(croak);

# VERSION

# ABSTRACT: Collect linux load average statistics.

=head1 SYNOPSIS

    use Linux::Info::LoadAVG;

    my $lxs  = Linux::Info::LoadAVG->new;
    my $stat = $lxs->get;

=head1 DESCRIPTION

Linux::Info::LoadAVG gathers the load average from the virtual F</proc> filesystem (procfs).

For more information read the documentation of the front-end module L<Linux::Info>.

=head1 LOAD AVERAGE STATISTICS

Generated by F</proc/loadavg>.

    avg_1   -  The average processor workload of the last minute.
    avg_5   -  The average processor workload of the last five minutes.
    avg_15  -  The average processor workload of the last fifteen minutes.

=head1 METHODS

=head2 new()

Call C<new()> to create a new object.

    my $lxs = Linux::Info::LoadAVG->new;

It's possible to set the path to the proc filesystem.

     Linux::Info::LoadAVG->new(
        files => {
            # This is the default
            path    => '/proc',
            loadavg => 'loadavg',
        }
    );

=head2 get()

Call C<get()> to get the statistics. C<get()> returns the statistics as a hash reference.

    my $stat = $lxs->get;

=head1 EXPORTS

Nothing.

=head1 SEE ALSO

=over

=item *

B<proc(5)>

=item *

L<Linux::Info>

=back

=cut

sub new {
    my $class = shift;
    my $opts  = ref( $_[0] ) ? shift : {@_};

    my %self = (
        files => {
            path    => '/proc',
            loadavg => 'loadavg',
        }
    );

    foreach my $file ( keys %{ $opts->{files} } ) {
        $self{files}{$file} = $opts->{files}->{$file};
    }

    return bless \%self, $class;
}

sub get {
    my $self  = shift;
    my $class = ref $self;
    my $file  = $self->{files};
    my %lavg  = ();

    my $filename =
      $file->{path} ? "$file->{path}/$file->{loadavg}" : $file->{loadavg};
    open my $fh, '<', $filename
      or croak "$class: unable to open $filename ($!)";

    ( $lavg{avg_1}, $lavg{avg_5}, $lavg{avg_15} ) =
      ( split /\s+/, <$fh> )[ 0 .. 2 ];

    close($fh);
    return \%lavg;
}

1;
