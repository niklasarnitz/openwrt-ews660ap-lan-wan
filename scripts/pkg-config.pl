#!/usr/bin/perl

# lightweight no-dependency version of pkg-config. This will work on any machine
# with Perl installed.

# Copyright (C) 2012 M. Nunberg.
# You may use and distribute this software under the same terms and conditions
# as Perl itself.

package
    PkgConfig::Vars;
# this is a namespace for .pc files to hold their variables without
# relying on lexical scope.

package
    PkgConfig::UDefs;
# This namespace provides user-defined variables which are to override any
# declarations within the .pc file itself.

package PkgConfig;

#First two digits are Perl version, second two are pkg-config version
our $VERSION = '0.25026';

$VERSION =~ /([0-9]{2})$/;
my $compat_version = $1;

use strict;
use warnings;
use 5.006;
use Config;
use File::Spec;
use File::Glob 'bsd_glob';
use Class::Struct; #in core since 5.004
use File::Basename qw( dirname );
use Text::ParseWords qw( shellwords );

our $UseDebugging;

################################################################################
### Check for Log::Fu                                                        ###
################################################################################
BEGIN {
    my $ret = eval q{
        use Log::Fu 0.25 { level => "warn" };
        1;
    };

    if(!$ret) {
        my $log_base = sub {
            my (@args) = @_;
            print STDERR "[DEBUG] ", join(' ', @args);
            print STDERR "\n";
        };
        *log_debug = *log_debugf = sub { return unless $UseDebugging; goto &$log_base };
        *log_err = *log_errf = *log_warn = *log_warnf = *log_info = *log_infof =
            $log_base;

    }
}

our $VarClassSerial = 0;

################################################################################
### Sane Defaults                                                            ###
################################################################################
our @DEFAULT_SEARCH_PATH = qw(
    /usr/local/lib/pkgconfig /usr/local/share/pkgconfig
    /usr/lib/pkgconfig /usr/share/pkgconfig

);

our @DEFAULT_EXCLUDE_CFLAGS = qw(-I/usr/include -I/usr/local/include);
# don't include default link/search paths!
our @DEFAULT_EXCLUDE_LFLAGS = map { ( "-L$_", "-R$_" ) } qw( /lib /lib32 /lib64 /usr/lib /usr/lib32 /usr/lib/64 /usr/local/lib /usr/local/lib32 /usr/local/lib64 );

if($ENV{PKG_CONFIG_NO_OS_CUSTOMIZATION}) {

    # use the defaults regardless of detected platform

} elsif($ENV{PKG_CONFIG_LIBDIR}) {

    @DEFAULT_SEARCH_PATH = split $Config{path_sep}, $ENV{PKG_CONFIG_LIBDIR};

} elsif($^O eq 'msys') {

    # MSYS2 seems to actually set PKG_CONFIG_PATH in its /etc/profile
    # god bless it.  But.  The defaults if you unset the environment
    # variable are different
    @DEFAULT_SEARCH_PATH = qw(
        /usr/lib/pkgconfig
        /usr/share/pkgconfig
    );

} elsif($^O eq 'solaris' && $Config{ptrsize} == 8) {

    @DEFAULT_SEARCH_PATH = qw(
        /usr/local/lib/64/pkgconfig /usr/local/share/pkgconfig
        /usr/lib/64/pkgconfig /usr/share/pkgconfig
    );

} elsif($^O eq 'linux' and -f '/etc/gentoo-release') {
    # OK, we're running on Gentoo

    # Fetch ptrsize value
    my $ptrsize = $Config{ptrsize};

    # Are we running on 64 bit system?
    if ($ptrsize eq 8) {
        # We do
        @DEFAULT_SEARCH_PATH = qw!
          /usr/lib64/pkgconfig/ /usr/share/pkgconfig/
        !;
    } else {
        # We're running on a 32 bit system (hopefully)
        @DEFAULT_SEARCH_PATH = qw!
          /usr/lib/pkgconfig/ /usr/share/pkgconfig/
        !;
    }

} elsif($^O =~ /^(gnukfreebsd|linux)$/ && -r "/etc/debian_version") {

    my $arch;
    if(-x "/usr/bin/dpkg-architecture") {
        # works if dpkg-dev is installed
        # rt96694
        ($arch) = map { chomp; (split /=/)[1] }
                  grep /^DEB_HOST_MULTIARCH=/,
                  `/usr/bin/dpkg-architecture`;
    } elsif(-x "/usr/bin/gcc") {
        # works if gcc is installed
        $arch = `/usr/bin/gcc -dumpmachine`;
        chomp $arch;
    } else {
        my $deb_arch = `dpkg --print-architecture`;
        if($deb_arch =~ /^amd64/) {
            if($^O eq 'linux') {
                $arch = 'x86_64-linux-gnu';
            } elsif($^O eq 'gnukfreebsd') {
                $arch = 'x86_64-kfreebsd-gnu';
            }
        } elsif($deb_arch =~ /^i386/) {
            if($^O eq 'linux') {
                $arch = 'i386-linux-gnu';
            } elsif($^O eq 'gnukfreebsd') {
                $arch = 'i386-kfreebsd-gnu';
            }
        }
    }

    if($arch) {
        if(scalar grep /--print-foreign-architectures/, `dpkg --help`)
        {
            # multi arch support / Debian 7+
            @DEFAULT_SEARCH_PATH = (
                "/usr/local/lib/$arch/pkgconfig",
                "/usr/local/lib/pkgconfig",
                "/usr/local/share/pkgconfig",
                "/usr/lib/$arch/pkgconfig",
                "/usr/lib/pkgconfig",
                "/usr/share/pkgconfig",
            );

            push @DEFAULT_EXCLUDE_LFLAGS, map { ("-L$_", "-R$_") }
                "/usr/local/lib/$arch",
                "/usr/lib/$arch";

        } else {

            @DEFAULT_SEARCH_PATH = (
                "/usr/local/lib/pkgconfig",
                "/usr/local/lib/pkgconfig/$arch",
                "/usr/local/share/pkgconfig",
                "/usr/lib/pkgconfig",
                "/usr/lib/pkgconfig/$arch",
                "/usr/share/pkgconfig",
            );
        }

    } else {

        @DEFAULT_SEARCH_PATH = (
            "/usr/local/lib/pkgconfig",
            "/usr/local/share/pkgconfig",
            "/usr/lib/pkgconfig",
            "/usr/share/pkgconfig",
        );

    }

} elsif($^O eq 'linux' && -r "/etc/redhat-release") {

    if(-d "/usr/lib64/pkgconfig") {
        @DEFAULT_SEARCH_PATH = qw(
            /usr/lib64/pkgconfig
            /usr/share/pkgconfig
        );
    } else {
        @DEFAULT_SEARCH_PATH = qw(
            /usr/lib/pkgconfig
            /usr/share/pkgconfig
        );
    }

} elsif($^O eq 'linux' && -r "/etc/slackware-version") {

    # Fetch ptrsize value
    my $ptrsize = $Config{ptrsize};

    # Are we running on 64 bit system?
    if ($ptrsize == 8) {
        # We do
        @DEFAULT_SEARCH_PATH = qw!
          /usr/lib64/pkgconfig/ /usr/share/pkgconfig/
        !;
    } else {
        # We're running on a 32 bit system (hopefully)
        @DEFAULT_SEARCH_PATH = qw!
          /usr/lib/pkgconfig/ /usr/share/pkgconfig/
        !;
    }


} elsif($^O eq 'freebsd') {

    # TODO: FreeBSD 10-12's version of pkg-config does not
    # support PKG_CONFIG_DEBUG_SPEW so I can't verify
    # the path there.
    @DEFAULT_SEARCH_PATH = qw(
        /usr/local/libdata/pkgconfig
        /usr/libdata/pkgconfig
    );

} elsif($^O eq 'netbsd') {

    @DEFAULT_SEARCH_PATH = qw(
        /usr/pkg/lib/pkgconfig
        /usr/pkg/share/pkgconfig
        /usr/X11R7/lib/pkgconfig
        /usr/lib/pkgconfig
    );
} elsif($^O eq 'openbsd') {

    @DEFAULT_SEARCH_PATH = qw(
        /usr/lib/pkgconfig
        /usr/local/lib/pkgconfig
        /usr/local/share/pkgconfig
        /usr/X11R6/lib/pkgconfig
        /usr/X11R6/share/pkgconfig
    );

} elsif($^O eq 'MSWin32') {

    # Caveats:
    # 1. This pulls in Config,
    #    which we don't load on non MSWin32
    #    but it is in the core.
    # 2. Slight semantic difference in that we are treating
    #    Strawberry as the "system" rather than Windows, but
    #    since pkg-config is rarely used in MSWin32, it is
    #    better to have something that is useful rather than
    #    worry about if it is exactly the same as other
    #    platforms.
    # 3. It is a little brittle in that Strawberry might
    #    one day change its layouts.  If it has and you are
    #    reading this, please send a pull request or simply
    #    let me know -plicease
    require Config;
    if($Config::Config{myuname} =~ /strawberry-perl/)
    {
        #  handle PAR::Packer executables which have $^X eq "perl.exe"
        if ($ENV{PAR_0})
        {
            my $path = $ENV{PAR_TEMP};
            $path =~ s{\\}{/}g;
            @DEFAULT_SEARCH_PATH = ($path);
        }
        else {
            my($vol, $dir, $file) = File::Spec->splitpath($^X);
            my @dirs = File::Spec->splitdir($dir);
            splice @dirs, -3;
            my $path = (File::Spec->catdir($vol, @dirs, qw( c lib pkgconfig )));
            $path =~ s{\\}{/}g;
            @DEFAULT_SEARCH_PATH = $path;
        }
    }

    my @reg_paths;

    eval q{
        package
            PkgConfig::WinReg;

        use Win32API::Registry 0.21 qw( :ALL );

        foreach my $top (HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER) {
            my $key;
            RegOpenKeyEx( $top, "Software\\\\pkgconfig\\\\PKG_CONFIG_PATH", 0, KEY_READ, $key) || next;
            my $nlen = 1024;
            my $pos = 0;
            my $name = '';

            while(RegEnumValue($key, $pos++, $name, $nlen, [], [], [], [])) {
                my $type;
                my $data;
                RegQueryValueEx($key, $name, [], $type, $data, []);
                push @reg_paths, $data;
            }

            RegCloseKey( $key );
        }
    };

    unless($@) {
        unshift @DEFAULT_SEARCH_PATH, @reg_paths;
    }

    if($Config::Config{cc} =~ /cl(\.exe)?$/i)
    {
        @DEFAULT_EXCLUDE_LFLAGS = ();
        @DEFAULT_EXCLUDE_CFLAGS = ();
    }
    else
    {
        @DEFAULT_EXCLUDE_LFLAGS = (
            "-L/mingw/lib",
            "-R/mingw/lib",
            "-L/mingw/lib/pkgconfig/../../lib",
            "-R/mingw/lib/pkgconfig/../../lib",
        );
        @DEFAULT_EXCLUDE_CFLAGS = (
            "-I/mingw/include",
            "-I/mingw/lib/pkgconfig/../../include",
        );
    }

    # See caveats above for Strawberry and PAR::Packer
    require Config;
    if(not $ENV{PAR_0} and $Config::Config{myuname} =~ /strawberry-perl/)
    {
        my($vol, $dir, $file) = File::Spec->splitpath($^X);
        my @dirs = File::Spec->splitdir($dir);
        splice @dirs, -3;
        my $path = (File::Spec->catdir($vol, @dirs, qw( c )));
        $path =~ s{\\}{/}g;
        push @DEFAULT_EXCLUDE_LFLAGS, (
            "-L$path/lib",
            "-L$path/lib/pkgconfig/../../lib",
            "-R$path/lib",
            "-R$path/lib/pkgconfig/../../lib",
        );
        push @DEFAULT_EXCLUDE_CFLAGS, (
            "-I$path/include",
            "-I$path/lib/pkgconfig/../../include",
        );
    }
} elsif($^O eq 'darwin') {

    if(-x '/usr/local/Homebrew/bin/brew') {
        # Mac OS X with homebrew installed
        push @DEFAULT_SEARCH_PATH,
            bsd_glob '/usr/local/opt/*/lib/pkgconfig'
        ;
    }

}

my @ENV_SEARCH_PATH = split($Config{path_sep}, $ENV{PKG_CONFIG_PATH} || "");

unshift @DEFAULT_SEARCH_PATH, @ENV_SEARCH_PATH;

if($^O eq 'MSWin32') {
  @DEFAULT_SEARCH_PATH = map { s{\\}{/}g; $_ } map { /\s/ ? Win32::GetShortPathName($_) : $_ } @DEFAULT_SEARCH_PATH;
}

if($ENV{PKG_CONFIG_ALLOW_SYSTEM_CFLAGS}) {
    @DEFAULT_EXCLUDE_CFLAGS = ();
}

if($ENV{PKG_CONFIG_ALLOW_SYSTEM_LIBS}) {
    @DEFAULT_EXCLUDE_LFLAGS = ();
}

my $LD_OUTPUT_RE = qr/
    SEARCH_DIR\("
    ([^"]+)
    "\)
/x;

sub GuessPaths {
    my $pkg = shift;
    local $ENV{LD_LIBRARY_PATH} = "";
    local $ENV{C_INCLUDE_PATH} = "";
    local $ENV{LD_RUN_PATH} = "";

    my $ld = $ENV{LD} || 'ld';
    my $ld_output = qx(ld -verbose);
    my @defl_search_dirs = ($ld_output =~ m/$LD_OUTPUT_RE/g);

    @DEFAULT_EXCLUDE_LFLAGS = ();
    foreach my $path (@defl_search_dirs) {
        push @DEFAULT_EXCLUDE_LFLAGS, (map { "$_".$path }
            (qw(-R -L -rpath= -rpath-link= -rpath -rpath-link)));
    }
    log_debug("Determined exclude LDFLAGS", @DEFAULT_EXCLUDE_LFLAGS);

    #now get the include paths:
    my @cpp_output = qx(cpp --verbose 2>&1 < /dev/null);
    @cpp_output = map  { chomp $_; $_ } @cpp_output;
    #log_info(join("!", @cpp_output));
    while (my $cpp_line = shift @cpp_output) {
        chomp($cpp_line);
        if($cpp_line =~ /\s*#include\s*<.+search starts here/) {
            last;
        }
    }
    #log_info(@cpp_output);
    my @include_paths;
    while (my $path = shift @cpp_output) {
        if($path =~ /\s*End of search list/) {
            last;
        }
        push @include_paths, $path;
    }
    @DEFAULT_EXCLUDE_CFLAGS = map { "-I$_" } @include_paths;
    log_debug("Determine exclude CFLAGS", @DEFAULT_EXCLUDE_CFLAGS);
}


################################################################################
### Define our fields                                                        ###
################################################################################
struct(
    __PACKAGE__,
    [
     # .pc search paths, defaults to PKG_CONFIG_PATH in environment
     'search_path' => '@',

     # whether to also spit out static dependencies
     'static' => '$',

     # whether we replace references to -L and friends with -Wl,-rpath, etc.
     'rpath' => '$',

     # build rpath-search,

     # no recursion. set if we just want a version, or to see if the
     # package exists.
     'no_recurse' => '$',

     #list of cflags and ldflags to exclude
     'exclude_ldflags' => '@',
     'exclude_cflags' => '@',

     # what level of recursion we're at
     'recursion' => '$',

     # hash of libraries, keyed by recursion levels. Lower recursion numbers
     # will be listed first
     'libs_deplist' => '*%',

     # cumulative cflags and ldflags
     'ldflags'   => '*@',
     'cflags'    => '*@',

     # whether we print the c/ldflags
     'print_cflags' => '$',
     'print_ldflags' => '$',

     # information about our top-level package
     'pkg'  => '$',
     'pkg_exists' => '$',
     'pkg_version' => '$',
     'pkg_url', => '$',
     'pkg_description' => '$',
     'errmsg'   => '$',

     # classes used for storing persistent data
     'varclass' => '$',
     'udefclass' => '$',
     'filevars' => '*%',
     'uservars' => '*%',

     # options for printing variables
     'print_variables' => '$',
     'print_variable' => '$',
     'print_values' => '$',
     'defined_variables' => '*%',

     # for creating PkgConfig objects with identical
     # settings
     'original' => '$',
    ]
);

################################################################################
################################################################################
### Variable Storage                                                         ###
################################################################################
################################################################################

sub _get_pc_varname {
    my ($self,$vname_base) = @_;
    $self->varclass . "::" . $vname_base;
}

sub _get_pc_udefname {
    my ($self,$vname_base) = @_;
    $self->udefclass . "::" . $vname_base;
}

sub _pc_var {
    my ($self,$vname) = @_;
    $vname =~ s,\.,DOT,g;
    no strict 'refs';
    $vname = $self->_get_pc_varname($vname);
    no warnings qw(once);
    my $glob = *{$vname};
    $glob ? $$glob : ();
}

sub _quote_cvt($)  {
    join ' ', map { s/(\s|"|')/\\$1/g; $_ } shellwords(shift)
}

sub assign_var {
    my ($self,$field,$value) = @_;
    no strict 'refs';

    # if the user has provided a definition, use that.
    if(exists ${$self->udefclass."::"}{$field}) {
        log_debug("Prefix already defined by user");
        return;
    }
    my $evalstr = sprintf('$%s = PkgConfig::_quote_cvt(%s)',
                    $self->_get_pc_varname($field), $value);

    log_debug("EVAL", $evalstr);
    do {
        no warnings 'uninitialized';
        eval $evalstr;
    };
    if($@) {
        log_err($@);
    }
}

sub prepare_vars {
    my $self = shift;
    my $varclass = $self->varclass;
    no strict 'refs';

    %{$varclass . "::"} = ();

    while (my ($name,$glob) = each %{$self->udefclass."::"}) {
        my $ref = *$glob{SCALAR};
        next unless defined $ref;
        ${"$varclass\::$name"} = $$ref;
    }
}

################################################################################
################################################################################
### Initializer                                                              ###
################################################################################
################################################################################
sub find {
    my ($cls,$library,%options) = @_;
    my @uspecs = (
        ['search_path', \@DEFAULT_SEARCH_PATH],
        ['exclude_ldflags', \@DEFAULT_EXCLUDE_LFLAGS],
        ['exclude_cflags', \@DEFAULT_EXCLUDE_CFLAGS]
    );

    my %original = %options;

    foreach (@uspecs) {
        my ($basekey,$default) = @$_;
        my $list = [ @{$options{$basekey} ||= [] } ];
        if($options{$basekey . "_override"}) {
            @$list = @{ delete $options{$basekey."_override"} };
        } else {
            push @$list, @$default;
        }

        $options{$basekey} = $list;
        #print "$basekey: " . Dumper($list);
    }

    $VarClassSerial++;
    $options{varclass} = sprintf("PkgConfig::Vars::SERIAL_%d", $VarClassSerial);
    $options{udefclass} = sprintf("PkgConfig::UDefs::SERIAL_%d", $VarClassSerial);
    $options{original} = \%original;


    my $udefs = delete $options{VARS} || {};

    while (my ($k,$v) = each %$udefs) {
        no strict 'refs';
        my $vname = join('::', $options{udefclass}, $k);
        ${$vname} = $v;
    }

    my $o = $cls->new(%options);

    my @libraries;
    if(ref $library eq 'ARRAY') {
        @libraries = @$library;
    } else {
        @libraries = ($library);
    }

    if($options{file_path}) {

        if(-r $options{file_path}) {
            $o->recursion(1);
            $o->parse_pcfile($options{file_path});
            $o->recursion(0);
        } else {
            $o->errmsg("No such file $options{file_path}\n");
        }

    } else {

        foreach my $lib (@libraries) {
            $o->recursion(0);
            my($op,$ver);
            ($lib,$op,$ver) = ($1,$2,PkgConfig::Version->new($3))
                if $lib =~ /^(.*)\s+(!=|=|>=|<=|>|<)\s+(.*)$/;
            $o->find_pcfile($lib);

            if(!$o->errmsg && defined $op) {
                $op = '==' if $op eq '=';
                unless(eval qq{ PkgConfig::Version->new(\$o->pkg_version) $op \$ver })
                {
                    $o->errmsg("Requested '$lib $op $ver' but version of $lib is " .
                        ($o->pkg_version ? $o->pkg_version : '') . "\n");
                }
            }
        }
    }

    $o;
}

################################################################################
################################################################################
### Modify our flags stack                                                   ###
################################################################################
################################################################################
sub append_ldflags {
    my ($self,@flags) = @_;
    my @ld_flags = _split_flags(@flags);

    foreach my $ldflag (@ld_flags) {
        next unless $ldflag =~ /^-Wl/;

        my (@wlflags) = split(/,/, $ldflag);
        shift @wlflags; #first is -Wl,
        filter_omit(\@wlflags, $self->exclude_ldflags);

        if(!@wlflags) {
            $ldflag = "";
            next;
        }

        $ldflag = join(",", '-Wl', @wlflags);
    }

    @ld_flags = grep $_, @ld_flags;
    return unless @ld_flags;

    push @{($self->libs_deplist->{$self->recursion} ||=[])},
        @ld_flags;
}

# notify us about extra compiler flags
sub append_cflags {
    my ($self,@flags) = @_;
    push @{$self->cflags}, _split_flags(@flags);
}


################################################################################
################################################################################
### All sorts of parsing is here                                             ###
################################################################################
################################################################################
sub get_requires {
    my ($self,$requires) = @_;
    return () unless $requires;

    my @reqlist = split(/[\s,]+/, $requires);
    my @ret;
    while (defined (my $req = shift @reqlist) ) {
        my $reqlet = [ $req ];
        push @ret, $reqlet;
        last unless @reqlist;
        #check if we need some version scanning:

        my $cmp_op;
        my $want;

        GT_PARSE_REQ:
        {
            #all in one word:
            ($cmp_op) = ($req =~ /([<>=]+)/);
            if($cmp_op) {
                if($req =~ /[<>=]+$/) {
                    log_debug("comparison operator spaced ($cmp_op)");
                    ($want) = ($req =~ /([^<>=]+$)/);
                    $want ||= shift @reqlist;
                } else {
                    $want = shift @reqlist;
                }
                push @$reqlet, ($cmp_op, $want);
            } elsif ($reqlist[0] =~ /[<>=]+/) {
                $req = shift @reqlist;
                goto GT_PARSE_REQ;
            }
        }
    }
    #log_debug(@ret);
    @ret;
}


sub parse_line {
    my ($self,$line,$evals) = @_;
    no strict 'vars';

    $line =~ s/#[^#]+$//g; # strip comments
    return unless $line;

    my ($tok) = ($line =~ /([=:])/);

    my ($field,$value) = split(/[=:]/, $line, 2);
    return unless defined $value;

    if($tok eq '=') {
        $self->defined_variables->{$field} = $value;
    }

    #strip trailing/leading whitespace:
    $field =~ s/(^\s+)|(\s+)$//msg;

    #remove trailing/leading whitespace from value
    $value =~ s/(^\s+)|(\s+$)//msg;

    log_debugf("Field %s, Value %s", $field, $value);

    $field = lc($field);

    #perl variables can't have '.' in them:
    $field =~ s/\./DOT/g;

    #remove quotes from field names
    $field =~ s/['"]//g;


    # pkg-config escapes a '$' with a '$$'. This won't go in perl:
    $value =~ s/[^\\]\$\$/\\\$/g;
    $value =~ s/([@%&])/\$1/g;


    # append our pseudo-package for persistence.
    my $varclass = $self->varclass;
    $value =~ s/(\$\{[^}]+\})/lc($1)/ge;

    $value =~ s/\$\{/\$\{$varclass\::/g;

    # preserve quoted space
    $value = join ' ', map { s/(["'])/\\$1/g; "'$_'" } shellwords $value
      if $value =~ /[\\"']/;

    #quote the value string, unless quoted already
    $value = "\"$value\"";

    #get existent variables from our hash:


    #$value =~ s/'/"/g; #allow for interpolation
    $self->assign_var($field, $value);

}

sub parse_pcfile {
    my ($self,$pcfile,$wantversion) = @_;
    #log_warn("Requesting $pcfile");
    open my $fh, "<", $pcfile or die "$pcfile: $!";

    $self->prepare_vars();

    my @lines = (<$fh>);
    close($fh);

    my $text = join("", @lines);
    $text =~ s,\\[\r\n],,g;
    @lines = split(/[\r\n]/, $text);

    my @eval_strings;

    #Fold lines:

    my $pcfiledir = dirname $pcfile;
    $pcfiledir =~ s{\\}{/}g;

    foreach my $line ("pcfiledir=$pcfiledir", @lines) {
        $self->parse_line($line, \@eval_strings);
    }

    #now that we have eval strings, evaluate them all within the same
    #lexical scope:


    $self->append_cflags(  $self->_pc_var('cflags') );
    if($self->static) {
        $self->append_cflags( $self->_pc_var('cflags.private') );
    }
    $self->append_ldflags( $self->_pc_var('libs') );
    if($self->static) {
        $self->append_ldflags( $self->_pc_var('libs.private') );
    }

    my @deps;
    my @deps_dynamic = $self->get_requires( $self->_pc_var('requires'));
    my @deps_static = $self->get_requires( $self->_pc_var('requires.private') );
    @deps = @deps_dynamic;


    if($self->static) {
        push @deps, @deps_static;
    }

    if($self->recursion == 1 && (!$self->pkg_exists())) {
        $self->pkg_version( $self->_pc_var('version') );
        $self->pkg_url( $self->_pc_var('url') );
        $self->pkg_description( $self->_pc_var('description') );
        $self->pkg_exists(1);
    }

    unless ($self->no_recurse) {
        foreach (@deps) {
            my ($dep,$cmp_op,$version) = @$_;
            $dep = "$dep $cmp_op $version" if defined $cmp_op;
            my $other = PkgConfig->find($dep, %{ $self->original });
            if($other->errmsg) {
                $self->errmsg($other->errmsg);
                last;
            }
            $self->append_cflags(  $other->get_cflags );
            $self->append_ldflags( $other->get_ldflags );
        }
    }
}


################################################################################
################################################################################
### Locate and process a .pc file                                            ###
################################################################################
################################################################################
sub find_pcfile {
    my ($self,$libname,$version) = @_;

    $self->recursion($self->recursion + 1);

    my $pcfile = "$libname.pc";
    my $found = 0;
    my @found_paths = (grep {
        -e File::Spec->catfile($_, $pcfile)
        } @{$self->search_path});

    if(!@found_paths) {
        my @search_paths = @{$self->search_path};
        $self->errmsg(
            join("\n",
                 "Can't find $pcfile in any of @search_paths",
                 "use the PKG_CONFIG_PATH environment variable, or",
                 "specify extra search paths via 'search_paths'",
                 ""
                )
        ) unless $self->errmsg();
        return;
    }

    $pcfile = File::Spec->catfile($found_paths[0], $pcfile);

    $self->parse_pcfile($pcfile);

    $self->recursion($self->recursion - 1);
}

################################################################################
################################################################################
### Public Getters                                                           ###
################################################################################
################################################################################

sub _return_context (@) {
    wantarray ? (@_) : join(' ', map { s/(\s|['"])/\\$1/g; $_ } @_)
}

sub get_cflags {
    my $self = shift;
    my @cflags = @{$self->cflags};

    filter_omit(\@cflags, $self->exclude_cflags);
    filter_dups(\@cflags);
    _return_context @cflags;
}

sub get_ldflags {
    my $self = shift;
    my @ordered_libs;
    my @lib_levels = sort keys %{$self->libs_deplist};
    my @ret;

    @ordered_libs = @{$self->libs_deplist}{@lib_levels};
    foreach my $liblist (@ordered_libs) {
        my $lcopy = [ @$liblist ];
        filter_dups($lcopy);
        filter_omit($lcopy, $self->exclude_ldflags);
        push @ret, @$lcopy;
    }

    @ret = reverse @ret;
    filter_dups(\@ret);
    @ret = reverse(@ret);
    _return_context @ret;
}

sub get_var {
    my($self, $name) = @_;
    $self->_pc_var($name);
}

sub get_list {
    my $self = shift;
    my @search_paths = @{$self->search_path};
    my @rv = ();
    $self->recursion(0);
    for my $d (@search_paths) {
        next unless -d $d;
        for my $pc (bsd_glob("$d/*.pc")) {
            if ($pc =~ m|/([^\\\/]+)\.pc$|) {
                $self->parse_pcfile($pc);
                push @rv, [$1, $self->_pc_var('name') . ' - ' . $self->_pc_var('description')];
            }
        }
    }
    @rv;
}


################################################################################
################################################################################
### Utility functions                                                        ###
################################################################################
################################################################################

#split a list of tokens by spaces
sub _split_flags {
    my @flags = @_;
    if(!@flags) {
        return @flags;
    }
    if(@flags == 1) {
        my $str = shift @flags;
        return () if !$str;
        #@flags = map { s/\\(\s)/$1/g; $_ } split(/(?<!\\)\s+/, $str);
        @flags = shellwords $str;
    }
    @flags = grep $_, @flags;
    @flags;
}



sub filter_dups {
    my $array = shift;
    my @ret;
    my %seen_hash;
    #@$array = reverse @$array;
    foreach my $elem (@$array) {
        if(exists $seen_hash{$elem}) {
            next;
        }
        $seen_hash{$elem} = 1;
        push @ret, $elem;
    }
    #print Dumper(\%seen_hash);
    @$array = @ret;
}

sub filter_omit {
    my ($have,$exclude) = @_;
    my @ret;
    #print Dumper($have);
    foreach my $elem (@$have) {
        #log_warn("Checking '$elem'");
        if(grep { $_ eq $elem } @$exclude) {
            #log_warn("Found illegal flag '$elem'");
            next;
        }
        push @ret, $elem;
    }
    @$have = @ret;
}

sub version_2_array {
    my $string = shift;
    my @chunks = split(/\./, $string);
    my @ret;
    my $chunk;
    while( ($chunk = pop @chunks)
        && $chunk =~ /^\d+$/) {
        push @ret, $chunk;
    }
    @ret;
}


sub version_check {
    my ($want,$have) = @_;
    my @a_want = version_2_array($want);
    my @a_have = version_2_array($have);

    my $max_elem = scalar @a_want > scalar @a_have
        ? scalar @a_have
        : scalar @a_want;

    for(my $i = 0; $i < $max_elem; $i++) {
        if($a_want[$i] > $a_have[$i]) {
            return 0;
        }
    }
    1;
}


if(caller) {
    return 1;
}

package
    PkgConfig::Version;

use overload
    '<=>' => sub { $_[0]->cmp($_[1]) },
    '""'  => sub { $_[0]->as_string },
    fallback => 1;

sub new {
    my($class, $value) = @_;
    bless [split /\./, defined $value ? $value : ''], $class;
}

sub clone {
    __PACKAGE__->new(shift->as_string);
}

sub as_string {
    my($self) = @_;
    join '.', @{ $self };
}

sub cmp {
    my($self, $other) = @_;
    no warnings 'uninitialized';
    defined($self->[0]) || defined($other->[0]) ? ($self->[0] <=> $other->[0]) || &cmp([@{$self}[1..$#$self]], [@{$other}[1..$#$other]]) : 0;
}

################################################################################
################################################################################
################################################################################
################################################################################
### Script-Only stuff                                                        ###
################################################################################
################################################################################
################################################################################
################################################################################
package PkgConfig::Script;
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;

my $print_errors = 0;
my @ARGV_PRESERVE = @ARGV;

my @POD_USAGE_SECTIONS = (
    "NAME",
    'DESCRIPTION/SCRIPT OPTIONS/USAGE',
    "DESCRIPTION/SCRIPT OPTIONS/ARGUMENTS|ENVIRONMENT",
    "AUTHOR & COPYRIGHT"
);

my @POD_USAGE_OPTIONS = (
    -verbose => 99,
    -sections => \@POD_USAGE_SECTIONS
);

GetOptions(
    'libs' => \my $PrintLibs,
    'libs-only-L' => \my $PrintLibsOnlyL,
    'libs-only-l' => \my $PrintLibsOnlyl,
    'libs-only-other' => \my $PrintLibsOnlyOther,
    'list-all' => \my $ListAll,
    'static' => \my $UseStatic,
    'cflags' => \my $PrintCflags,
    'cflags-only-I' => \my $PrintCflagsOnlyI,
    'cflags-only-other' => \my $PrintCflagsOnlyOther,
    'exists' => \my $PrintExists,
    'atleast-version=s' => \my $AtLeastVersion,
    'atleast-pkgconfig-version=s' => \my $AtLeastPkgConfigVersion,
    'exact-version=s'   => \my $ExactVersion,
    'max-version=s'     => \my $MaxVersion,

    'silence-errors' => \my $SilenceErrors,
    'print-errors' => \my $PrintErrors,
    'errors-to-stdout' => \my $ErrToStdOut,
    'short-errors'     => \my $ShortErrors,

    'define-variable=s', => \my %UserVariables,

    'print-variables' => \my $PrintVariables,
    'print-values'  => \my $PrintValues,
    'variable=s',   => \my $OutputVariableValue,

    'modversion'    => \my $PrintVersion,
    'version',      => \my $PrintAPIversion,
    'real-version' => \my $PrintRealVersion,

    'debug'         => \my $Debug,
    'with-path=s',    => \my @ExtraPaths,
    'env-only',     => \my $EnvOnly,
    'guess-paths',  => \my $GuessPaths,

    'h|help|?'      => \my $WantHelp
) or pod2usage(@POD_USAGE_OPTIONS);

if($^O eq 'msys' && !$ENV{PKG_CONFIG_NO_OS_CUSTOMIZATION}) {
    $UseStatic = 1;
}

if($WantHelp) {
    pod2usage(@POD_USAGE_OPTIONS, -exitval => 0);
}

if($Debug) {
    eval {
    Log::Fu::set_log_level('PkgConfig', 'DEBUG');
    };
    $PkgConfig::UseDebugging = 1;
}

if($GuessPaths) {
    PkgConfig->GuessPaths();
}

if($PrintAPIversion) {
    print '0.', $compat_version, "\n";
    exit(0);
}

if($AtLeastPkgConfigVersion) {
    my($major,$minor,$patch) = split /\./, $AtLeastPkgConfigVersion;
    exit 1 if $major > 0;
    exit 1 if $minor > $compat_version;
    exit 1 if $minor == $compat_version && $patch > 0;
    exit 0;
}

if($PrintRealVersion) {

    printf STDOUT ("ppkg-config - cruftless pkg-config\n" .
            "Version: %s\n", $PkgConfig::VERSION);
    exit(0);
}

if($PrintErrors) {
    $print_errors = 1;
}

if($SilenceErrors) {
    $print_errors = 0;
}

# This option takes precedence over all other options
# be it:
# --silence-errors
# or
# --print-errors
if ($ErrToStdOut) {
 $print_errors = 2;
}

my $WantFlags = ($PrintCflags || $PrintLibs || $PrintLibsOnlyL || $PrintCflagsOnlyI || $PrintCflagsOnlyOther || $PrintLibsOnlyOther || $PrintLibsOnlyl || $PrintVersion);

if($WantFlags) {
    $print_errors = 1 unless $SilenceErrors;
}

my %pc_options;
if($PrintExists || $AtLeastVersion || $ExactVersion || $MaxVersion || $PrintVersion) {
    $pc_options{no_recurse} = 1;
}


$pc_options{static} = $UseStatic;
$pc_options{search_path} = \@ExtraPaths;

if($EnvOnly) {
    delete $pc_options{search_path};
    $pc_options{search_path_override} = [ @ExtraPaths, @ENV_SEARCH_PATH];
}

$pc_options{print_variables} = $PrintVariables;
$pc_options{print_values} = $PrintValues;
$pc_options{VARS} = \%UserVariables;

if($ListAll) {
    my $o = PkgConfig->find([], %pc_options);
    my @list = $o->get_list();

    # can't use List::Util::max as it wasn't core until Perl 5.8
    my $max_length = 0;
    foreach my $length (map { length $_->[0] } @list) {
        $max_length = $length if $length > $max_length;
    }

    printf "%-${max_length}s %s\n", $_->[0], $_->[1] for @list;
    exit(0);
}

my @FINDLIBS = @ARGV or die "Must specify at least one library";

if($AtLeastVersion) {
    @FINDLIBS = map { "$_ >= $AtLeastVersion" } @FINDLIBS;
} elsif($MaxVersion) {
    @FINDLIBS = map { "$_ <= $MaxVersion" } @FINDLIBS;
} elsif($ExactVersion) {
    @FINDLIBS = map { "$_ = $ExactVersion" } @FINDLIBS;
}

my $o = PkgConfig->find(\@FINDLIBS, %pc_options);

if($o->errmsg) {
    # --errors-to-stdout
    if ($print_errors == 2) {
        print STDOUT $o->errmsg;
    # --print-errors
    } elsif ($print_errors == 1) {
        print STDERR $o->errmsg;
    }
    # --silence-errors
    exit(1);
}

if($o->print_variables) {
    while (my ($k,$v) = each %{$o->defined_variables}) {
        print $k;
        if($o->print_values) {
            print "=$v";
        } else {
            print "\n";
        }
    }
}

if($OutputVariableValue) {
    my $val = ($o->_pc_var($OutputVariableValue) or "");
    print $val . "\n";
}

if(!$WantFlags) {
    exit(0);
}

if($PrintVersion) {
    print $o->pkg_version . "\n";
    exit(0);
}

my @print_flags;

if($PrintCflags) {
    @print_flags = $o->get_cflags;
}

if($PrintCflagsOnlyI) {
    @print_flags = grep /^-I/, $o->get_cflags;
}

if($PrintCflagsOnlyOther) {
    @print_flags = grep /^-[^I]/, $o->get_cflags;
}

if($PrintLibs) {
    @print_flags = $o->get_ldflags;
}

if ($PrintLibsOnlyOther) {
    @print_flags = grep /^-[^LRl]/, $o->get_ldflags;
}

# handle --libs-only-L and --libs-only-l but watch the case when
# we got 'ppkg-config --libs-only-L --libs-only-l foo' which must behave just like
# 'ppkg-config --libs-only-l foo'

if($PrintLibsOnlyl or ($PrintLibsOnlyl and $PrintLibsOnlyL)) {
    @print_flags = grep /^-l/, $o->get_ldflags;
} elsif ($PrintLibsOnlyL) {
    @print_flags = grep /^-[LR]/, $o->get_ldflags;
}

print scalar PkgConfig::_return_context(@print_flags);
print "\n";
exit(0);
