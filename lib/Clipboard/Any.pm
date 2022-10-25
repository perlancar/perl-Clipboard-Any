package Clipboard::Any;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter::Rinci qw(import);
use File::Which qw(which);
use IPC::System::Options 'system', 'readpipe', -log=>1;

# AUTHORITY
# DATE
# DIST
# VERSION

my $known_clipboard_managers = [qw/klipper/];
my $sch_clipboard_manager = ['str', in=>$known_clipboard_managers];
our %argspecopt_clipboard_manager = (
    clipboard_manager => {
        summary => 'Explicitly set clipboard manager to use',
        schema => $sch_clipboard_manager,
        description => <<'_',

The default, when left undef, is to detect what clipboard manager is running.

_
    },
);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Common interface to clipboard manager functions',
    description => <<'_',

This module provides common functions related to clipboard manager.

Supported clipboard manager: KDE Plasma's Klipper (`klipper`). Support for more
clipboard managers, e.g. on Windows or other Linux desktop environment is
welcome.

_
};

$SPEC{'detect_clipboard_manager'} = {
    v => 1.1,
    summary => 'Detect which clipboard manager program is currently running',
    description => <<'_',

Will return a string containing name of clipboard manager program, e.g.
`klipper`. Will return undef if no known clipboard manager is detected.

_
    result_naked => 1,
    result => {
        schema => $sch_clipboard_manager,
    },
};
sub detect_clipboard_manager {
    my %args = @_;

    #require Proc::Find;
    #no warnings 'once';
    #local $Proc::Find::CACHE = 1;

  KLIPPER:
    {
        log_trace "Checking whether clipboard manager klipper is running ...";
        unless (which "qdbus") {
            log_trace "qdbus not found in PATH, system is probably not using klipper";
            last;
        }
        my $out;
        system({capture_merged=>\$out}, "qdbus", "org.kde.klipper", "/klipper");
        unless ($? == 0) {
            # note, when klipper is disabled via System Tray Settings > General
            # > Extra Items, the object path /klipper disappears.
            log_trace "Failed listing org.kde.klipper /klipper methods, system is probably not using klipper";
            last;
        }
        log_trace "Concluding klipper is active";
        return "klipper";
    }

    log_trace "No known clipboard manager is detected";
    undef;
}

$SPEC{'clear_clipboard_history'} = {
    v => 1.1,
    summary => 'Delete all clipboard items',
    description => <<'_',

_
    args => {
        %argspecopt_clipboard_manager,
    },
};
sub clear_clipboard_history {
    my %args = @_;

    my $clipboard_manager = $args{clipboard_manager} // detect_clipboard_manager();
    return [412, "Can't detect any known clipboard manager"]
        unless $clipboard_manager;

    if ($clipboard_manager eq 'klipper') {
        my ($stdout, $stderr);
        # qdbus likes to emit an empty line
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "qdbus", "org.kde.klipper", "/klipper", "clearClipboardHistory");
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "/klipper's clearClipboardHistory failed: $exit_code"] if $exit_code;
        return [200, "OK"];
    }

    [412, "Cannot clear clipboard history (clipboard manager=$clipboard_manager)"];
}

$SPEC{'clear_clipboard_content'} = {
    v => 1.1,
    summary => 'Delete current clipboard content',
    description => <<'_',

_
    args => {
        %argspecopt_clipboard_manager,
    },
};
sub clear_clipboard_content {
    my %args = @_;

    my $clipboard_manager = $args{clipboard_manager} // detect_clipboard_manager();
    return [412, "Can't detect any known clipboard manager"]
        unless $clipboard_manager;

    if ($clipboard_manager eq 'klipper') {
        my ($stdout, $stderr);
        # qdbus likes to emit an empty line
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "qdbus", "org.kde.klipper", "/klipper", "clearClipboardContents");
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "/klipper's clearClipboardContents failed: $exit_code"] if $exit_code;
        return [200, "OK"];
    }

    [412, "Cannot clear clipboard content (clipboard manager=$clipboard_manager)"];
}

$SPEC{'get_clipboard_content'} = {
    v => 1.1,
    summary => 'Get the clipboard content (most recent, history index [0])',
    description => <<'_',

Caveats for klipper: Non-text item is not retrievable by getClipboardContents().
If the current item is e.g. an image, then the next text item from history will
be returned instead, or empty string if none exists.

_
    args => {
        %argspecopt_clipboard_manager,
    },
    examples => [
        {
            summary => 'Munge text (remove duplicate spaces) in clipboard',
            src_plang => 'bash',
            src => q{[[prog]] | perl -lpe's/ {2,}/ /g' | clipadd},
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub get_clipboard_content {
    my %args = @_;

    my $clipboard_manager = $args{clipboard_manager} // detect_clipboard_manager();
    return [412, "Can't detect any known clipboard manager"]
        unless $clipboard_manager;

    if ($clipboard_manager eq 'klipper') {
        my ($stdout, $stderr);
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "qdbus", "org.kde.klipper", "/klipper", "getClipboardContents");
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "/klipper's getClipboardContents failed: $exit_code"] if $exit_code;
        chomp $stdout;
        return [200, "OK", $stdout];
    }

    [412, "Cannot get clipboard content (clipboard manager=$clipboard_manager)"];
}

$SPEC{'list_clipboard_history'} = {
    v => 1.1,
    summary => 'List the clipboard history',
    description => <<'_',

Caveats for klipper: 1) Klipper does not provide method to get the length of
history. So we retrieve history item one by one using getClipboardHistoryItem(i)
from i=0, i=1, and so on. And assume that if we get two consecutive empty
string, it means we reach the end of the clipboard history before the first
empty result.

2) Non-text items are not retrievable by getClipboardHistoryItem().

_
    args => {
        %argspecopt_clipboard_manager,
    },
};
sub list_clipboard_history {
    my %args = @_;

    my $clipboard_manager = $args{clipboard_manager} // detect_clipboard_manager();
    return [412, "Can't detect any known clipboard manager"]
        unless $clipboard_manager;

    if ($clipboard_manager eq 'klipper') {
        my @rows;
        my $i = 0;
        my $got_empty;
        while (1) {
            my ($stdout, $stderr);
            system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "qdbus", "org.kde.klipper", "/klipper", "getClipboardHistoryItem", $i);
            my $exit_code = $? < 0 ? $? : $?>>8;
            return [500, "/klipper's getClipboardHistoryItem($i) failed: $exit_code"] if $exit_code;
            chomp $stdout;
            if ($stdout eq '') {
                log_trace "Got empty result";
                if ($got_empty++) {
                    pop @rows;
                    last;
                } else {
                    push @rows, $stdout;
                }
            } else {
                log_trace "Got result '%s'", $stdout;
                $got_empty = 0;
                push @rows, $stdout;
            }
            $i++;
        }
        return [200, "OK", \@rows];
    }

    [412, "Cannot list clipboard history (clipboard manager=$clipboard_manager)"];
}

$SPEC{'add_clipboard_content'} = {
    v => 1.1,
    summary => 'Add a new content to the clipboard',
    description => <<'_',

_
    args => {
        %argspecopt_clipboard_manager,
        content => {schema => 'str*', pos=>0, cmdline_src=>'stdin_or_args'},
    },
    examples => [
        {
            summary => 'Munge text (remove duplicate spaces) in clipboard',
            src_plang => 'bash',
            src => q{clipget | perl -lpe's/ {2,}/ /g' | [[prog]]},
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub add_clipboard_content {
    my %args = @_;

    my $clipboard_manager = $args{clipboard_manager} // detect_clipboard_manager();
    return [412, "Can't detect any known clipboard manager"]
        unless $clipboard_manager;

    defined $args{content} or
        return [400, "Please specify content"];

    if ($clipboard_manager eq 'klipper') {
        my ($stdout, $stderr);
        # qdbus likes to emit an empty line
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "qdbus", "org.kde.klipper", "/klipper", "setClipboardContents", $args{content});
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "/klipper's setClipboardContents failed: $exit_code"] if $exit_code;
        return [200, "OK"];
    }

    [412, "Cannot add clipboard content (clipboard manager=$clipboard_manager)"];
}

1;
# ABSTRACT:

=head1 DESCRIPTION

This module provides a common interface to interact with clipboard.

Some terminology:

=over

=item * clipboard content

The current clipboard content. Some clipboard manager supports storing multiple
items (multiple contents). All the items are called L</clipboard history>.

=item * clipboard history

Some clipboard manager supports storing multiple items (multiple contents). All
the items are called clipboard history. It is presented as an array. The current
item/content is at index 0, the secondmost current item is at index 1, and so
on.

=back


=head1 NOTES

2021-07-15 - Tested on my system (KDE Plasma 5.12.9 on Linux).
