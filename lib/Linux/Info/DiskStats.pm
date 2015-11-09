package Linux::Info::DiskStats;

use strict;
use warnings;
use Carp qw(croak);
use Time::HiRes 1.9726;
use YAML::Syck 1.29;

=head1 NAME

Linux::Info::DiskStats - Collect linux disk statistics.

=head1 SYNOPSIS

    use Linux::Info::DiskStats;

    my $lxs = Linux::Info::DiskStats->new;
    $lxs->init;
    sleep 1;
    my $stat = $lxs->get;

Or

    my $lxs = Linux::Info::DiskStats->new(initfile => $file);
    $lxs->init;
    my $stat = $lxs->get;

=head1 DESCRIPTION

Linux::Info::DiskStats gathers disk statistics from the virtual F</proc> filesystem (procfs).

For more information read the documentation of the front-end module L<Linux::Info>.

=head1 DISK STATISTICS

Generated by F</proc/diskstats> or F</proc/partitions>.

    major   -  The mayor number of the disk
    minor   -  The minor number of the disk
    rdreq   -  Number of read requests that were made to physical disk per second.
    rdbyt   -  Number of bytes that were read from physical disk per second.
    wrtreq  -  Number of write requests that were made to physical disk per second.
    wrtbyt  -  Number of bytes that were written to physical disk per second.
    ttreq   -  Total number of requests were made from/to physical disk per second.
    ttbyt   -  Total number of bytes transmitted from/to physical disk per second.

=head1 METHODS

=head2 new()

Call C<new()> to create a new object.

    my $lxs = Linux::Info::DiskStats->new;

Maybe you want to store/load the initial statistics to/from a file:

    my $lxs = Linux::Info::DiskStats->new(initfile => '/tmp/diskstats.yml');

If you set C<initfile> it's not necessary to call sleep before C<get()>.

It's also possible to set the path to the proc filesystem.

     Linux::Info::DiskStats->new(
        files => {
            # This is the default
            path       => '/proc',
            diskstats  => 'diskstats',
            partitions => 'partitions',
        }
    );

=head2 init()

Call C<init()> to initialize the statistics.

    $lxs->init;

=head2 get()

Call C<get()> to get the statistics. C<get()> returns the statistics as a hash reference.

    my $stat = $lxs->get;

=head2 raw()

Get raw values.

=head1 EXPORTS

Nothing.

=head1 SEE ALSO

=over

=item *

B<proc(5)>

=item *

L<Linux::Info>

=back

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 of Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

This file is part of Linux Info project.

Linux-Info is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Linux-Info is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Linux Info.  If not, see <http://www.gnu.org/licenses/>.

=cut

sub new {
    my $class = shift;
    my $opts = ref( $_[0] ) ? shift : {@_};

    my %self = (
        files => {
            path       => '/proc',
            diskstats  => 'diskstats',
            partitions => 'partitions',
        },

        # --------------------------------------------------------------
        # The sectors are equivalent with blocks and have a size of 512
        # bytes since 2.4 kernels. This value is needed to calculate the
        # amount of disk i/o's in bytes.
        # --------------------------------------------------------------
        blocksize => 512,
    );

    if ( defined $opts->{initfile} ) {
        $self{initfile} = $opts->{initfile};
    }

    foreach my $file ( keys %{ $opts->{files} } ) {
        $self{files}{$file} = $opts->{files}->{$file};
    }

    if ( $opts->{blocksize} ) {
        $self{blocksize} = $opts->{blocksize};
    }

    return bless \%self, $class;
}

sub init {
    my $self = shift;

    if ( $self->{initfile} && -r $self->{initfile} ) {
        $self->{init} = YAML::Syck::LoadFile( $self->{initfile} );
        $self->{time} = delete $self->{init}->{time};
    }
    else {
        $self->{time} = Time::HiRes::gettimeofday();
        $self->{init} = $self->_load;
    }
}

sub get {
    my $self  = shift;
    my $class = ref $self;

    if ( !exists $self->{init} ) {
        croak "$class: there are no initial statistics defined";
    }

    $self->{stats} = $self->_load;
    $self->_deltas;

    if ( $self->{initfile} ) {
        $self->{init}->{time} = $self->{time};
        YAML::Syck::DumpFile( $self->{initfile}, $self->{init} );
    }

    return $self->{stats};
}

sub raw {
    my $self = shift;
    my $raw  = $self->_load;

    return $raw;
}

#
# private stuff
#

sub _load {
    my $self  = shift;
    my $class = ref $self;
    my $file  = $self->{files};
    my $bksz  = $self->{blocksize};
    my ( %stats, $fh );

 # -----------------------------------------------------------------------------
 # one of the both must be opened for the disk statistics!
 # if diskstats (2.6) doesn't exists then let's try to read
 # the partitions (2.4)
 #
 # /usr/src/linux/Documentation/iostat.txt shortcut
 #
 # ... the statistics fields are those after the device name.
 #
 # Field  1 -- # of reads issued
 #     This is the total number of reads completed successfully.
 # Field  2 -- # of reads merged, field 6 -- # of writes merged
 #     Reads and writes which are adjacent to each other may be merged for
 #     efficiency.  Thus two 4K reads may become one 8K read before it is
 #     ultimately handed to the disk, and so it will be counted (and queued)
 #     as only one I/O.  This field lets you know how often this was done.
 # Field  3 -- # of sectors read
 #     This is the total number of sectors read successfully.
 # Field  4 -- # of milliseconds spent reading
 #     This is the total number of milliseconds spent by all reads (as
 #     measured from __make_request() to end_that_request_last()).
 # Field  5 -- # of writes completed
 #     This is the total number of writes completed successfully.
 # Field  7 -- # of sectors written
 #     This is the total number of sectors written successfully.
 # Field  8 -- # of milliseconds spent writing
 #     This is the total number of milliseconds spent by all writes (as
 #     measured from __make_request() to end_that_request_last()).
 # Field  9 -- # of I/Os currently in progress
 #     The only field that should go to zero. Incremented as requests are
 #     given to appropriate request_queue_t and decremented as they finish.
 # Field 10 -- # of milliseconds spent doing I/Os
 #     This field is increases so long as field 9 is nonzero.
 # Field 11 -- weighted # of milliseconds spent doing I/Os
 #     This field is incremented at each I/O start, I/O completion, I/O
 #     merge, or read of these stats by the number of I/Os in progress
 #     (field 9) times the number of milliseconds spent doing I/O since the
 #     last update of this field.  This can provide an easy measure of both
 #     I/O completion time and the backlog that may be accumulating.
 # -----------------------------------------------------------------------------

    my $file_diskstats =
      $file->{path} ? "$file->{path}/$file->{diskstats}" : $file->{diskstats};
    my $file_partitions =
      $file->{path} ? "$file->{path}/$file->{partitions}" : $file->{partitions};

    if ( open $fh, '<', $file_diskstats ) {
        while ( my $line = <$fh> ) {

#                   --      --      --      F1     F2     F3     F4     F5     F6     F7     F8    F9    F10   F11
#                   $1      $2      $3      $4     --     $5     --     $6     --     $7     --    --    --    --
            if ( $line =~
/^\s+(\d+)\s+(\d+)\s+(.+?)\s+(\d+)\s+\d+\s+(\d+)\s+\d+\s+(\d+)\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+$/
              )
            {
                for my $x ( $stats{$3} ) {    # $3 -> the device name
                    $x->{major}  = $1;
                    $x->{minor}  = $2;
                    $x->{rdreq}  = $4;            # Field 1
                    $x->{rdbyt}  = $5 * $bksz;    # Field 3
                    $x->{wrtreq} = $6;            # Field 5
                    $x->{wrtbyt} = $7 * $bksz;    # Field 7
                    $x->{ttreq} += $x->{rdreq} + $x->{wrtreq};
                    $x->{ttbyt} += $x->{rdbyt} + $x->{wrtbyt};
                }
            }

 # -----------------------------------------------------------------------------
 # Field  1 -- # of reads issued
 #     This is the total number of reads issued to this partition.
 # Field  2 -- # of sectors read
 #     This is the total number of sectors requested to be read from this
 #     partition.
 # Field  3 -- # of writes issued
 #     This is the total number of writes issued to this partition.
 # Field  4 -- # of sectors written
 #     This is the total number of sectors requested to be written to
 #     this partition.
 # -----------------------------------------------------------------------------
 #                      --      --      --      F1      F2      F3      F4
 #                      $1      $2      $3      $4      $5      $6      $7
            elsif ( $line =~
                /^\s+(\d+)\s+(\d+)\s+(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/ )
            {
                for my $x ( $stats{$3} ) {    # $3 -> the device name
                    $x->{major}  = $1;
                    $x->{minor}  = $2;
                    $x->{rdreq}  = $4;            # Field 1
                    $x->{rdbyt}  = $5 * $bksz;    # Field 2
                    $x->{wrtreq} = $6;            # Field 3
                    $x->{wrtbyt} = $7 * $bksz;    # Field 4
                    $x->{ttreq} += $x->{rdreq} + $x->{wrtreq};
                    $x->{ttbyt} += $x->{rdbyt} + $x->{wrtbyt};
                }
            }
        }
        close($fh);
    }
    elsif ( open $fh, '<', $file_partitions ) {
        while ( my $line = <$fh> ) {

#                           --      --     --     --      F1     F2     F3     F4     F5     F6     F7     F8    F9    F10   F11
#                           $1      $2     --     $3      $4     --     $5     --     $6     --     $7     --    --    --    --
            next
              unless $line =~
/^\s+(\d+)\s+(\d+)\s+\d+\s+(.+?)\s+(\d+)\s+\d+\s+(\d+)\s+\d+\s+(\d+)\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+$/;
            for my $x ( $stats{$3} ) {    # $3 -> the device name
                $x->{major}  = $1;
                $x->{minor}  = $2;
                $x->{rdreq}  = $4;            # Field 1
                $x->{rdbyt}  = $5 * $bksz;    # Field 3
                $x->{wrtreq} = $6;            # Field 5
                $x->{wrtbyt} = $7 * $bksz;    # Field 7
                $x->{ttreq} += $x->{rdreq} + $x->{wrtreq};
                $x->{ttbyt} += $x->{rdbyt} + $x->{wrtbyt};
            }
        }
        close($fh);
    }
    else {
        croak "$class: unable to open $file_diskstats or $file_partitions ($!)";
    }

    if ( !-e $file_diskstats || !scalar %stats ) {
        croak
"$class: no diskstats found! your system seems not to be compiled with CONFIG_BLK_STATS=y";
    }

    return \%stats;
}

sub _deltas {
    my $self  = shift;
    my $class = ref $self;
    my $istat = $self->{init};
    my $lstat = $self->{stats};
    my $time  = Time::HiRes::gettimeofday();
    my $delta = sprintf( '%.2f', $time - $self->{time} );
    $self->{time} = $time;

    foreach my $dev ( keys %{$lstat} ) {
        if ( !exists $istat->{$dev} ) {
            delete $lstat->{$dev};
            next;
        }

        my $idev = $istat->{$dev};
        my $ldev = $lstat->{$dev};

        while ( my ( $k, $v ) = each %{$ldev} ) {
            next if $k =~ /^major\z|^minor\z/;

            if ( !defined $idev->{$k} ) {
                croak "$class: not defined key found '$k'";
            }

            if ( $v !~ /^\d+\z/ || $ldev->{$k} !~ /^\d+\z/ ) {
                croak "$class: invalid value for key '$k'";
            }

            if ( $ldev->{$k} == $idev->{$k} || $idev->{$k} > $ldev->{$k} ) {
                $ldev->{$k} = sprintf( '%.2f', 0 );
            }
            elsif ( $delta > 0 ) {
                $ldev->{$k} =
                  sprintf( '%.2f', ( $ldev->{$k} - $idev->{$k} ) / $delta );
            }
            else {
                $ldev->{$k} = sprintf( '%.2f', $ldev->{$k} - $idev->{$k} );
            }

            $idev->{$k} = $v;
        }
    }
}

1;
