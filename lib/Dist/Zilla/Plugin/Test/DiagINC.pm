use 5.008001;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::DiagINC;
# ABSTRACT: Add Test::DiagINC to all .t files

our $VERSION = '0.003';

use Moose;
with(
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [':TestFiles'],
    },
    'Dist::Zilla::Role::PPI',
    'Dist::Zilla::Role::PrereqSource',
);

use PPI;
use Syntax::Keyword::Junction qw/any/;
use namespace::autoclean;

sub munge_files {
    my ($self) = @_;
    $self->munge_file($_) for grep { $_->name =~ /\.t$/ } @{ $self->found_files };
}

sub munge_file {
    my ( $self, $file ) = @_;

    my $document = $self->ppi_document_for_file($file);

    # using ::Comment is a hack for adding code copied from PkgVersion
    my $add =
      PPI::Token::Comment->new(q[use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC'; ]);

    my $was_munged;

    # XXX should errors get reported? -- xdg, 2014-02-04
    eval {
        my @includes = @{ $document->find('PPI::Statement::Include') };

        for my $s (@includes) {
            next if $s->version;
            next if $s->module eq any(qw/strict warnings/);
            $was_munged = $s->first_token->insert_before($add);
            last;
        }
    };

    if ($was_munged) {
        $self->save_ppi_document_to_file( $document, $file );
        $self->log_debug( [ "added Test::DiagINC line to %s", $file->name ] );
    }
    else {
        $self->log( [ "skipping %s: couldn't add Test::DiagINC line", $file->name ] );
    }

}

sub register_prereqs {
    my $self = shift;

    $self->zilla->register_prereqs(
        {
            phase => 'test',
            type  => 'requires',
        },
        'Test::DiagINC' => '0.002',
    );
}

__PACKAGE__->meta->make_immutable;

1;

=for Pod::Coverage BUILD munge_files munge_file register_prereqs

=head1 SYNOPSIS

    # in dist.ini
    [Test::DiagINC]

=head1 DESCRIPTION

This L<Dist::Zilla> plugin adds the following L<Test::DiagINC> line to all
C<.t> files under the C<t/> directory:

    use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC';

It will be inserted before the first module loaded (without adding a line
to preserve line numbering), excluding C<strict> and C<warnings>.  This
makes sure that it is loaded before L<Test::More>, which L<Test::DiagINC>
requires.

For example, it will turn this:

    use 5.008001;
    use strict;
    use warnings;

    use Test::More;
    # etc.

Into this:

    use 5.008001;
    use strict;
    use warnings;

    use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC'; use Test::More;
    # etc.

=head1 RATIONALE

Prerequisite reporting modules like L<Dist::Zilla::Plugin::Test::ReportPrereqs>
and similar modules give an overview of prerequisites, but don't generally list
I<deep> dependencies — i.e. the modules used by the modules you use.

L<Dist::Zilla::Plugin::Test::PrereqsFromMeta> offers a feature to report from
C<%INC> after loading all prerequisites, but it doesn't cover all types of
dependencies and can't account for optional dependencies.

What I find most relevant is knowing exactly what modules are loaded when any
given test fails.  This would include test modules, optional modules and so on.
It is I<specific> to the failure situation.

That sort of output is also verbose, so this plugin only generates that output
if C<$ENV{AUTOMATED_TESTING}> is true.  That means it will show up on CPAN
Testers, but not clutter up manual test output, which seems to me like the
right trade-off.

=cut

# vim: ts=4 sts=4 sw=4 et:
