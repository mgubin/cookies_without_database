package App::Controller::Form;
use strict;
use warnings;
use parent 'App::Base';
use Data::Dumper;
use Template;
use App::Helper::Web;

sub new {
    my $class  = shift;
    my %params = @_;

    my $self = $class->SUPER::new(
        config => undef,
        logger => undef,

        _template_dir     => '../tpl/',
        _template_content => {
            get  => 'form',
            post => 'result',
        },
        _template_ext => 'htm',

        %params,
    );

    $class = ref $class if ref $class;
    bless $self, $class;

    return $self;
}

sub process {
    my $self = shift;

    if ( $self->_web->is_method_get() ) {
        $self->_render_form();
    } elsif ( $self->_web->is_method_post() ) {
        $self->_render_post_result();
    } else {
        $self->_web->return_status('405 Method Not Allowed');
    }

    return 1;
}

sub _template {
    my $self = shift;

    unless ( $self->{_template} ) {
        $self->{_template} = Template->new( INCLUDE_PATH => $self->_get('_template_dir') );
    }

    return $self->{_template};
}

sub _render_form {
    my $self = shift;

    my $config = $self->_config;
    $self->_render_page(
        template => $self->_get('_template_content')->{get},
        data     => {
            captcha_width    => $config->{captcha}{width},
            captcha_height   => $config->{captcha}{height},
            captcha_length   => $config->{captcha}{code_lenght},
            captcha_precheck => $config->{captcha}{precheck},
            time             => time,
        },
    );
}

sub _render_post_result {
    my $self = shift;

    my $captcha = $self->_web->value('сaptcha');
    $self->_log("Check captcha: got code $captcha");
    my $hash        = $self->_web->get_cookie( $self->_config->{captcha}{cookie} );
    my $cookie_hash = $self->_web->get_cookie( $self->_config->{captcha}{cookie} );
    $self->_log("Check captcha: hash from cookie $cookie_hash");

    my $data =
        $self->_check_captcha( $captcha, $hash )
        ? {
            result  => 1,
            message => 'Capture is good',
        }
        : {
            result  => 0,
            message => 'Capture is wrong',
        };

    $self->_log("Check captcha result: $data->{message}");
    $self->_render_page(
        template => $self->_get('_template_content')->{post},
        data     => $data,
    );
}

sub _render_page {
    my $self   = shift;
    my %params = @_;

    my $output;
    my $template_file = "$params{template}." . $self->_get('_template_ext');

    unless ( $self->_template->process( $template_file, $params{data}, \$output ) ) {
        $self->_web->return_status( '500 ' . $self->_template->error() );
    }

    $self->_web->print_header();
    print $output;
}

sub _check_captcha {
    my ( $self, $captcha, $hash ) = @_;

    return $self->_captcha->is_valid( $captcha, $hash );
}

1;

__END__

=head1 NAME

App::Controller::Form - Контроллер вывода страницы в браузер

=head1 SYNOPSIS

use App::Controller::Form;
my $web = App::Controller::Form->new( config => hash, logger => object );
$web->process();

=head1 METHODS

=item my $web = App::Controller::Form->new( %parameters );

Конструктор объекта. В качестве входным должен получить следующие параметры:
config  Хэш с конфигурацией приложения
logger  Объект логгера

=item $web->process();

Запуск процесса вывода страниц

=cut
