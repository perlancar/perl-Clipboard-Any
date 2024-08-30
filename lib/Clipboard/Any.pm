package Clipboard::Any;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter::Rinci qw(import);
use IPC::System::Options 'system', 'readpipe', 'run', -log=>1;

# AUTHORITY
# DATE
# DIST
# VERSION

my $known_clipboard_managers = [qw/klipper parcellite clipit xclip/];
my $sch_clipboard_manager = ['str', in=>$known_clipboard_managers];
our %argspecopt_clipboard_manager = (
    clipboard_manager => {
        summary => 'Explicitly set clipboard manager to use',
        schema => $sch_clipboard_manager,
        description => <<'MARKDOWN',

The default, when left undef, is to detect what clipboard manager is running.

MARKDOWN
        cmdline_aliases => {m=>{}},
    },
);

our %argspec0_index = (
    index => {
        summary => 'Index of item in history (0 means the current/latest, 1 the second latest, and so on)',
        schema => 'int*',
        description => <<'MARKDOWN',

If the index exceeds the number of items in history, empty string or undef will
be returned instead.

MARKDOWN
    },
);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Common interface to clipboard manager functions',
    description => <<'MARKDOWN',

This module provides common functions related to clipboard manager.

Supported clipboard manager: KDE Plasma's Klipper (`klipper`), `parcellite`,
`clipit`, `xclip`. Support for more clipboard managers, e.g. on Windows or other
Linux desktop environment is welcome.

MARKDOWN
};

$SPEC{'detect_clipboard_manager'} = {
    v => 1.1,
    summary => 'Detect which clipboard manager program is currently running',
    description => <<'MARKDOWN',

Will return a string containing name of clipboard manager program, e.g.
`klipper`. Will return undef if no known clipboard manager is detected.

MARKDOWN
    result_naked => 1,
    result => {
        schema => $sch_clipboard_manager,
    },
};
sub detect_clipboard_manager {
    my %args = @_;

    require File::Which;

  KLIPPER:
    {
        log_trace "Checking whether clipboard manager klipper is running ...";
        unless (File::Which::which("qdbus")) {
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
        log_trace "org.kde.klipper/klipper object active, concluding using klipper";
        return "klipper";
    }

    require Proc::Find;
    no warnings 'once';
    local $Proc::Find::CACHE = 1;

  PARCELLITE:
    {
        log_trace "Checking whether clipboard manager parcellite is running ...";
        my @pids = Proc::Find::find_proc(name => "parcellite");
        if (@pids) {
            log_trace "parcellite process is running, concluding using parcellite";
            return "parcellite";
        } else {
            log_trace "parcellite process does not seem to be running, probably not using parcellite";
        }
    }

  CLIPIT:
    {
        # basically the same as parcellite
        log_trace "Checking whether clipboard manager clipit is running ...";
        my @pids = Proc::Find::find_proc(name => "clipit");
        if (@pids) {
            log_trace "clipit process is running, concluding using clipit";
            return "clipit";
        } else {
            log_trace "clipit process does not seem to be running, probably not using clipit";
        }
    }

  XCLIP:
    {
        log_trace "Checking whether xclip is available ...";
        unless (File::Which::which("xclip")) {
            log_trace "xclip not found in PATH, skipping choosing xclip";
            last;
        }
        log_trace "xclip found in PATH, concluding using xclip";
        return "xclip";
    }

    log_trace "No known clipboard manager is detected";
    undef;
}

$SPEC{'clear_clipboard_history'} = {
    v => 1.1,
    summary => 'Delete all clipboard items',
    description => <<'MARKDOWN',

MARKDOWN
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
    } elsif ($clipboard_manager eq 'parcellite') {
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'clipit') {
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'xclip') {
        # implemented by setting both primary and clipboard to empty string

        my $fh;

        open $fh, "| xclip -i -selection primary" ## no critic: InputOutput::ProhibitTwoArgOpen
            or return [500, "xclip -i -selection primary failed (1): $!"];
        print $fh '';
        close $fh
            or return [500, "xclip -i -selection primary failed (2): $!"];

        open $fh, "| xclip -i -selection clipboard" ## no critic: InputOutput::ProhibitTwoArgOpen
            or return [500, "xclip -i -selection clipboard failed (1): $!"];
        print $fh '';
        close $fh
            or return [500, "xclip -i -selection clipboard failed (2): $!"];

        return [200, "OK"];
    }

    [412, "Cannot clear clipboard history (clipboard manager=$clipboard_manager)"];
}

$SPEC{'clear_clipboard_content'} = {
    v => 1.1,
    summary => 'Delete current clipboard content',
    description => <<'MARKDOWN',

MARKDOWN
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
    } elsif ($clipboard_manager eq 'parcellite') {
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'clipit') {
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'xclip') {
        # implemented by setting primary to empty string

        open my $fh, "| xclip -i -selection primary" ## no critic: InputOutput::ProhibitTwoArgOpen
            or return [500, "xclip -i -selection primary failed (1): $!"];
        print $fh '';
        close $fh
            or return [500, "xclip -i -selection primary failed (2): $!"];

        return [200, "OK"];
    }

    [412, "Cannot clear clipboard content (clipboard manager=$clipboard_manager)"];
}

$SPEC{'get_clipboard_content'} = {
    v => 1.1,
    summary => 'Get the clipboard content (most recent, history index [0])',
    description => <<'MARKDOWN',

Caveats for klipper: Non-text item is not retrievable by getClipboardContents().
If the current item is e.g. an image, then the next text item from history will
be returned instead, or empty string if none exists.

MARKDOWN
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
    } elsif ($clipboard_manager eq 'parcellite') {
        my ($stdout, $stderr);
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "parcellite", "-p");
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "parcellite command failed with exit code $exit_code"] if $exit_code;
        return [200, "OK", $stdout];
    } elsif ($clipboard_manager eq 'clipit') {
        my ($stdout, $stderr);
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "clipit", "-p");
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "clipit command failed with exit code $exit_code"] if $exit_code;
        return [200, "OK", $stdout];
    } elsif ($clipboard_manager eq 'xclip') {
        my ($stdout, $stderr);
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "xclip", "-o", "-selection", "primary");
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "xclip -o failed with exit code $exit_code"] if $exit_code;
        return [200, "OK", $stdout];
    }

    [412, "Cannot get clipboard content (clipboard manager=$clipboard_manager)"];
}

$SPEC{'list_clipboard_history'} = {
    v => 1.1,
    summary => 'List the clipboard history',
    description => <<'MARKDOWN',

Caveats for klipper: 1) Klipper does not provide method to get the length of
history. So we retrieve history item one by one using getClipboardHistoryItem(i)
from i=0, i=1, and so on. And assume that if we get two consecutive empty
string, it means we reach the end of the clipboard history before the first
empty result.

2) Non-text items are not retrievable by getClipboardHistoryItem().

MARKDOWN
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
    } elsif ($clipboard_manager eq 'parcellite') {
        # parcellite -c usually just prints the same result as -p (primary)
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'clipit') {
        # clipit -c usually just prints the same result as -p (primary)
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'xclip') {
        my ($stdout, $stderr, $exit_code);
        my @rows;

        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "xclip", "-o", "-selection", "primary");
        $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "xclip -o (primary) failed with exit code $exit_code"] if $exit_code;
        push @rows, $stdout;

        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "xclip", "-o", "-selection", "clipboard");
        $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "xclip -o (clipboard) failed with exit code $exit_code"] if $exit_code;
        push @rows, $stdout;

        return [200, "OK", \@rows];
    }

    [412, "Cannot list clipboard history (clipboard manager=$clipboard_manager)"];
}

$SPEC{'get_clipboard_history_item'} = {
    v => 1.1,
    summary => 'Get a clipboard history item',
    description => <<'MARKDOWN',

MARKDOWN
    args => {
        %argspecopt_clipboard_manager,
        %argspec0_index,
    },
};
sub get_clipboard_history_item {
    my %args = @_;
    my $index = $args{index};

    my $clipboard_manager = $args{clipboard_manager} // detect_clipboard_manager();
    return [412, "Can't detect any known clipboard manager"]
        unless $clipboard_manager;

    if ($clipboard_manager eq 'klipper') {
        my ($stdout, $stderr);
        system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
               "qdbus", "org.kde.klipper", "/klipper", "getClipboardHistoryItem", $index);
        my $exit_code = $? < 0 ? $? : $?>>8;
        return [500, "/klipper's getClipboardHistoryItem($index) failed: $exit_code"] if $exit_code;
        chomp $stdout;
        return [200, "OK", $stdout];
    } elsif ($clipboard_manager eq 'parcellite') {
        # parcellite -c usually just prints the same result as -p (primary)
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'clipit') {
        # clipit -c usually just prints the same result as -p (primary)
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'xclip') {
        my ($stdout, $stderr, $exit_code);
        my @rows;

        if ($index == 0) {
            system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
                   "xclip", "-o", "-selection", "primary");
            $exit_code = $? < 0 ? $? : $?>>8;
            return [500, "xclip -o (primary) failed with exit code $exit_code"] if $exit_code;
            return [200, "OK", $stdout];
        } elsif ($index == 0) {
            system({capture_stdout=>\$stdout, capture_stderr=>\$stderr},
                   "xclip", "-o", "-selection", "clipboard");
            $exit_code = $? < 0 ? $? : $?>>8;
            return [500, "xclip -o (clipboard) failed with exit code $exit_code"] if $exit_code;
            return [200, "OK", $stdout];
        } else {
            return [200, "OK", undef];
        }
    }

    [412, "Cannot get clipboard history item (clipboard manager=$clipboard_manager)"];
}

$SPEC{'add_clipboard_content'} = {
    v => 1.1,
    summary => 'Add a new content to the clipboard',
    description => <<'MARKDOWN',

For `xclip`: when adding content, the primary selection is set. The clipboard
content is unchanged.

MARKDOWN
    args => {
        %argspecopt_clipboard_manager,
        content => {
            schema => 'str*',
            pos=>0,
            cmdline_src=>'stdin_or_args',
        },
        tee => {
            summary => 'If set to true, will output content back to STDOUT',
            schema => 'bool*',
        },
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
        print $args{content} if $args{tee};
        return [200, "OK"];
    } elsif ($clipboard_manager eq 'parcellite') {
        # parcellite cli copies unknown options and stdin to clipboard history
        # but not as the current one
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'clipit') {
        # clipit cli copies unknown options and stdin to clipboard history but
        # not as the current one
        return [501, "Not yet implemented"];
    } elsif ($clipboard_manager eq 'xclip') {
        open my $fh, "| xclip -i -selection primary" ## no critic: InputOutput::ProhibitTwoArgOpen
            or return [500, "xclip -i -selection primary failed (1): $!"];
        print $fh $args{content};
        close $fh
            or return [500, "xclip -i -selection primary failed (2): $!"];
        print $args{content} if $args{tee};
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


=head2 Supported clipboard managers

=head3 Klipper

The default clipboard manager on KDE Plasma.

=head3 clipit

=head3 parcellite

=head3 xclip

This is not a "real" clipboard manager, but just an interface to the X
selections. With C<xclip>, the history is viewed as having two items. The
first/recent is the primary selection and the second one is the secondary.


=head1 NOTES

2021-07-15 - Tested on my system (KDE Plasma 5.12.9 on Linux).
