package TriggerUpdate::Plugin;
use strict;
use File::Spec;

sub _trigger_update {
    my ( $cb, $app, $obj, $original ) = @_;
    my $rebuild;
    if ( $cb->name =~ /^scheduled_post/ ) {
        $rebuild = 1;
    } else {
        if ( defined $original ) {
            if ( ( $obj->status != $original->status )
                || ( $obj->title != $original->title )
                || ( $obj->authored_on != $original->authored_on ) ) {
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
    my $yaml = File::Spec->catfile( $plugin->path, 'YAML', 'triggers.yaml' );
    if (! $obj->blog->file_mgr->exists( $yaml ) ) {
        return 1;
    }
    my $update_triggers = MT::Util::YAML::LoadFile( $yaml );
    $update_triggers = $update_triggers->{ 'update_triggers' };
    my @entry_ids;
    my @index_ids;
    my @category_ids;
    my $continue;
    for my $trigger ( @$update_triggers ) {
        $trigger = $trigger->{ trigger };
        if ( ( $trigger->{ blog_id } == $obj->blog_id ) || $trigger->{ blog_id } == 0 ) {
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
                my $eids = $trigger->{ entry_ids };
                my $iids = $trigger->{ index_ids };
                my $cids = $trigger->{ category_ids };
                if ( $eids || $iids ) {
                    my @entries = split( /,/, $eids ) if $eids;
                    my @indexes = split( /,/, $iids ) if $iids;
                    my @categories = split( /,/, $cids ) if $cids;
                    push ( @entry_ids, @entries );
                    push ( @index_ids, @indexes );
                    push ( @category_ids, @categories );
                    $continue = 1;
                }
                # last;
            }
        }
    }
    return 1 unless $continue;
    require MT::WeblogPublisher;
    my $pub = MT::WeblogPublisher->new();
    my $has_hires = eval 'require Time::HiRes; 1' ? 1 : 0;
    if ( scalar @entry_ids ) {
        require MT::Entry;
        my @entries = MT::Entry->load( { id => \@entry_ids, class => [ 'entry', 'page' ] } );
        for my $entry ( @entries ) {
            my $start_time = $has_hires ? Time::HiRes::time() : time;
            $pub->start_time( $start_time );
            $pub->rebuild_entry(
                Entry => $entry,
                Blog => $entry->blog,
                BuildDependencies => 0 );
        }
    }
    if ( scalar @category_ids ) {
        require MT::FileInfo;
        my @categories_info = MT::FileInfo->load( { category_id => \@category_ids } );
        for my $fi ( @categories_info ) {
            my $start_time = $has_hires ? Time::HiRes::time() : time;
            $pub->start_time( $start_time );
            $pub->rebuild_from_fileinfo( $fi );
        }
    }
    if ( scalar @index_ids ) {
        require MT::Template;
        my @templates = MT::Template->load( { id => \@index_ids } );
        for my $tmpl ( @templates ) {
            my $start_time = $has_hires ? Time::HiRes::time() : time;
            $pub->start_time( $start_time );
            $pub->rebuild_indexes( Blog => $tmpl->blog, Template => $tmpl, Force => 1 );
        }
    }
    return 1;
}

1;