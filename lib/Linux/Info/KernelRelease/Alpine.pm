package Linux::Info::KernelRelease::Alpine;

use warnings;
use strict;
use parent 'Linux::Info::KernelRelease';
use Carp qw(confess);
use Class::XSAccessor getters => {
    get_binutils_version => 'binutils_version',
    get_alpine_patch     => 'alpine_patch'
};

# VERSION

# ABSTRACT: a subclass of Linux::Info::KernelRelease specific to parse Alpine kernel information

sub _set_proc_ver_regex {
    my $self = shift;

#Linux version 6.6.31-0-lts (buildozer@build-3-19-x86_64) (gcc (Alpine 13.2.1_git20231014) 13.2.1 20231014, GNU ld (GNU Binutils) 2.41) #1-Alpine SMP PREEMPT_DYNAMIC Fri, 17 May 2024 12:37:38 +0000
    $self->{proc_regex} =
qr/^Linux\sversion\s(?<version>\d+\.\d+\.\d+\-\d+\-?lts?)\s\((?<compiled_by>[\w\.\-\@]+)\)\s\(gcc\s\(.*\)\s(?<gcc_version>\d+\.\d+\.\d+)\s\d+,\sGNU\sld\s\(.*\)\s(?<binutils_version>\d+\.\d+)\)\s#\d-Alpine\s(?<type>\w+\s[\w+_]+)\s(?<build_datetime>.*)/;
}

=head1 METHODS

=head2 new

Extends parent method to further parse the kernel version string to fetch
additional information.

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    # 6.6.31-0-lts
    my $regex = qr/^\d+\.\d+\.\d+\-(\d+)(\-lts)?$/;

    if ( $self->{version} =~ $regex ) {
        $self->{alpine_patch} = $1 + 0;
        $self->{lts}          = 'lts' if ( defined($2) );
    }
    else {
        confess( 'Failed to match "' . $self->{version} . "\" against $regex" );
    }

    return $self;
}

=head2 get_binutils_version

Returns the binutils package version used to compile the kernel.

=head2 get_alpine_patch

Number of patches applied to the kernel by the Alpine maintainers.

=head2 is_lts

If the kernel is "Long-Term Support" or not.

=cut

sub is_lts {
    my $self = shift;
    return 1
      if ( ( defined $self->{lts} ) and ( $self->{lts} eq 'lts' ) );
    return 0;
}

1;
