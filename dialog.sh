#!/bin/bash


#set -e
set -u

. oobash.sh


## class Dialog
Dialog=(
    # Explicit definition is needed to make inheritance
    # possible.

    function __new__ = Dialog::__new__
    function __delete__ = Dialog::__delete__

    function show = Dialog::show

    function cmd = Dialog::cmd

    function add_args = Dialog::add_args
    function set_arg = Dialog::set_arg
    function arg = Dialog::arg
    function rmarg = Dialog::rmarg
    function arglen = Dialog::arglen

    function widget = Dialog::widget
    function text = Dialog::text
    function height = Dialog::height
    function width = Dialog::width

    function set_widget = Dialog::set_widget
    function set_text = Dialog::set_text
    function set_height = Dialog::set_height
    function set_width = Dialog::set_width

    declare temp_file
)


Dialog::__new__()
{
    local self=$1
    shift

    (( $# > 0 )) && { $self.set_text "$1"; shift; }
    (( $# > 0 )) && { $self.set_height "$1"; shift; }
    (( $# > 0 )) && { $self.set_width "$1"; shift; }

    [[ -z $($self.width) ]] && $self.set_width $(Dialog::MAXCOLS)
    [[ -z $($self.height) ]] && $self.set_height $(Dialog::MAXROWS)

    $self.set_temp_file "$(mktemp)"
}

Dialog::__delete__()
{
    clear

    rm -f $($1.temp_file)
}

Dialog::show()
{
    local self=$1
    shift

    eval dialog \"\${${self}___args[@]-}\"
}

Dialog::set_maxsize()
{
    local self=$1
    shift

    eval $(dialog --print-maxsize 2>&1| \
        awk -F'(MaxSize: *|, *)' '{print "\$self.set_width "$3";\$self.set_height "$2}')
    eval $($self._cmd)
}

Dialog::cmd()
{
    local self=$1
    shift

    eval echo dialog \"\${${self}___args[@]-}\"
}

Dialog::add_args()
{
    local self=$1
    shift

    local arglen

    while ! [[ -z ${1-} ]]; do
        eval arglen=\${#${self}___args}

        eval ${self}___args[$arglen]=\$1
        shift
    done
}


Dialog::set_arg()
{
    local self=$1
    shift

    eval ${self}___args[$1]=\$2
}


Dialog::arg()
{
    local self=$1
    shift

    eval echo \"\${${self}___args[$1]-}\"
}


Dialog::rmarg()
{
    local self=$1
    shift

    eval unset ${self}___args[$1]
    eval ${self}___args=\(\"\${${self}___args[@]}\"\)
}


Dialog::arglen()
{
    local self=$1
    shift

    eval echo \"\${#${self}___args[@]-}\"
}


Dialog::widget()
{
    local self=$1
    shift

    $self.arg 0
}


Dialog::set_widget()
{
    local self=$1
    shift

    $self.set_arg 0 "$1"
}


Dialog::text()
{
    local self=$1
    shift

    $self.arg 1
}


Dialog::set_text()
{
    local self=$1
    shift

    $self.set_arg 1 "$1"
}


Dialog::width()
{
    local self=$1
    shift

    $self.arg 3
}


Dialog::set_width()
{
    local self=$1
    shift

    $self.set_arg 3 "$1"
}


Dialog::height()
{
    local self=$1
    shift

    $self.arg 2
}


Dialog::set_height()
{
    local self=$1
    shift

    $self.set_arg 2 "$1"
}


Dialog::MAXCOLS()
{
    dialog --print-maxsize 2>&1| \
        awk -F'(MaxSize: *|, *)' '{print $3}'
}


Dialog::MAXROWS()
{
    dialog --print-maxsize 2>&1| \
        awk -F'(MaxSize: *|, *)' '{print $2}'
}

### end of class Dialog ###


## class MsgBox
MsgBox=("${Dialog[@]}"
    function __new__
)


MsgBox::__new__()
{
    Dialog::__new__ "$@"

    local self=$1

    $self.set_widget "--msgbox"
}

### end of class MsgBox ###


## class Menu
Menu=("${Dialog[@]}"
    function __new__

    function set_menu_height
    function menu_height
    function show
)

Menu::__new__()
{
    Dialog::__new__ "$@"

    local self=$1

    $self.set_widget "--menu"
}

Menu::set_menu_height()
{
    local self=$1
    shift

    $self.set_arg 4 "$1"
}

Menu::menu_height()
{
    local self=$1
    shift

    $self.arg 4
}

Menu::show()
{
    local self=$1
    shift

    local i=5


    while ! [[ -z ${1-} ]]; do
        $self.set_arg $i "$1"
        (( ++i ))

        shift
    done

    $self.cmd

    Dialog::show $self

    while (( $($self.arglen) > 5 )); do
        $self.rmarg $(( $($self.arglen) - 1 ))
    done
}


FileSelect=("${Dialog[@]}"
    function __new__

    function set_filepath
)

FileSelect::__new__()
{
    Dialog::__new__ "$@"

    $1.set_widget "--fselect"
}

FileSelect::set_filepath()
{
    local self=$1
    shift

    $self.set_text "$2"
}


new FileSelect fs ~
$fs.show

delete $fs
