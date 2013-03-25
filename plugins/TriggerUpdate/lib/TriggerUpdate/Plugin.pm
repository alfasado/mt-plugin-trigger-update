package TriggerUpdate::Plugin;
use strict;
use File::Spec;

sub _trigger_update {
    my ( $cb, $app, $obj, $original ) = @_;
    my $rebuild;
    if ( $cb->name eq 'scheduled_post_published' ) {
        $rebuild = 1;
    } else {
        if ( defined $original ) {
            if ( ( $obj->status != $original->status )
                || ( $obj->title != $original->title ) ) {
                $rebuild = 1;
            }
        } else {
            if ( $obj->status == 2 ) {
                $rebuild = 1;
            }
        }
    }
    return 1 unless $rebuild;
    my $plugin = MT->component( 'TriggerUpdate' );
    require MT::Util::YAML;
    my $yaml = File::Spec->catfile( $plugin->path, 'YAML', 'trigger.yaml' );
    if (! $obj->blog->file_mgr->exists( $yaml ) ) {
        return 1;
    }
    my $update_triggers = MT::Util::YAML::LoadFile( $yaml );
    $update_triggers = $update_triggers->{ 'update_triggers' };
    my @entry_ids;
    my $continue;
    for my $trigger ( @$update_triggers ) {
        $trigger = $trigger->{ trigger };
        if ( $trigger->{ blog_id } == $obj->blog_id ) {
            my $match;
            if ( $obj->class eq 'entry' ) {
                if ( $trigger->{ entry } ) {
                    $match = 1;
                }
            } elsif ( $obj->class eq 'entry' ) {
                if ( $trigger->{ page } ) {
                    $match = 1;
                }
            }
            if ( $match ) {
                my $ids = $trigger->{ entry_ids };
                @entry_ids = split( /,/, $ids );
                $continue = 1;
                last;
            }
        }
    }
    return 1 unless $continue;
    my @entries = MT::Entry->load( { id => \@entry_ids, class => [ 'entry', 'page' ] } );
    require MT::WeblogPublisher;
    my $pub = MT::WeblogPublisher->new;
    for my $entry ( @entries ) {
        $pub->rebuild_entry(
            Entry => $entry,
            Blog => $entry->blog,
            BuildDependencies => 0 );
    }
    return 1;
}

1;