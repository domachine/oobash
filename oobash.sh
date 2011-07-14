#!/bin/bash

# Oobash is a module which makes it possible to write
# pseudo-object-oriented bash-scripts.

# Copyright (C) 2010 Dominik Burgdörfer <dominik.burgdoerfer@googlemail.com>

# Oobash is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Oobash is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with oobash.  If not, see <http://www.gnu.org/licenses/>.



declare -A __OOB_OBJ_TABLE
declare -A __OOB_ADDR_TABLE


_create_var_mapper()
{
    local OBJ_NAME=$1
    local VALUE_FIELD=${2-}
    
    eval ${OBJ_NAME}_$2=${VALUE_FIELD-}

    local PREFIX=$(expr "${2-}" : '\(_*\)[a-zA-Z][a-zA-Z0-9_]*' || exit 0)
    local VAR=$(expr "${2-}" : '_*\([a-zA-Z][a-zA-Z0-9_]*\)' || exit 0)

    eval "$OBJ_NAME.${PREFIX-}${VAR}() { echo \"\$${OBJ_NAME}_$2\"; }"
    eval "$OBJ_NAME.${PREFIX-}${VAR}=() { ${OBJ_NAME}_$2=\$1; }"
}

_ArrayMapper=(
    function __new__

    function +=
#    function remove
    function size
)

_ArrayMapper::__new__()
{
    local self=$1
    shift

    eval ${self}__array=\(\)

    local count=0
    for i in "$@"; do
        eval ${self}__array[$count]=\$i

        (( ++count ))
    done
}

_ArrayMapper::+=()
{
    local self=$1
    shift

    local new_index
    new_index=$($self.size)

    (( new_index < 0 )) && new_index=0

    for i in "$@"; do
        eval ${self}__array[$new_index]=\$i

        (( ++new_index ))
    done
}

_ArrayMapper::size()
{
    local self=$1
    shift

    eval echo \${#${self}__array[@]}
}


_create_array_mapper()
{
    local OBJ_NAME=$1
    local VALUE_FIELD=${3-}

    new _ArrayMapper m ${VALUE_FIELD-}

    
    #eval ${OBJ_NAME}_$2=\$m

    local PREFIX=$(expr "${2-}" : '\(_*\)[a-zA-Z][a-zA-Z0-9_]*' || exit 0)
    local VAR=$(expr "${2-}" : '_*\([a-zA-Z][a-zA-Z0-9_]*\)' || exit 0)

    eval "$OBJ_NAME.${PREFIX-}${VAR}() { echo \"\${${m}__array[\$1]}\"; }"
    eval "$OBJ_NAME.${PREFIX-}${VAR}+=() { $m.+= \"\$@\"; }"
}


# Create new object without registering it in the object table.

# Arguments:
#    * unique objectname
#    * class name
#    * variable name to export object name to
#    * member declarations ...
new_metaobject()
{
    local OBJ_NAME=$1
    shift

    local CLASS=$1
    shift

    local VARNAME=$1
    shift

    local SHIFT
    local VALUE_FIELD
    local CLASS_FIELDS=1

    local PREFIX
    local VAR

    while ! [[ -z ${1-} ]]; do
        if [[ ${3-} = "=" ]]; then
            SHIFT=4
            VALUE_FIELD=${4-}
        else
            SHIFT=2
            VALUE_FIELD=  # empty
        fi

        if [[ $1 = "function" ]]; then
            [[ -z $VALUE_FIELD ]] && VALUE_FIELD=${CLASS}::$2
            eval "$OBJ_NAME.$2() { $VALUE_FIELD $OBJ_NAME \"\$@\"; }"
        elif [[ $1 = "declare" ]]; then
            if [[ $2 = "-a" ]]; then
                (( ++SHIFT ))
                _create_array_mapper "${OBJ_NAME}" "$3" "$VALUE_FIELD"
            else
                _create_var_mapper "${OBJ_NAME}" "$2" "$VALUE_FIELD"
            fi
            # eval ${OBJ_NAME}_$2=$VALUE_FIELD

            # PREFIX=$(expr "${2-}" : '\(_*\)[a-zA-Z][a-zA-Z0-9_]*' || exit 0)
            # VAR=$(expr "${2-}" : '_*\([a-zA-Z][a-zA-Z0-9_]*\)' || exit 0)

            # eval "$OBJ_NAME.${PREFIX-}${VAR}() { echo \"\$${OBJ_NAME}_$2\"; }"
            # eval "$OBJ_NAME.${PREFIX-}set_${VAR}() { ${OBJ_NAME}_$2=\$1; }"
        else
            echo -e "oobash: Syntax error in class-field $CLASS_FIELDS in class $CLASS,
\texpected function or declare keyword" >&2
            return 1
        fi

        (( ++CLASS_FIELDS ))
        shift $SHIFT
    done

    eval $VARNAME=$OBJ_NAME
    return 0
}


# Create new object and register it in the object table

# Arguments:
#    * Variable name of the class array
#    * Variable name to export object name to
#    + (optional) arguments to constructor.
new()
{
    local CLASS=$1
    shift

    local VARNAME=$1
    shift

    local i

    # Increment class id number.
    if [[ -z ${__OOB_OBJ_TABLE[$CLASS]-} ]]; then
        __OOB_OBJ_TABLE[$CLASS]=1
    else
        ((__OOB_OBJ_TABLE[$CLASS] += 1))
    fi


    # Generate unique object-name.
    local OBJ_NAME="${CLASS}_Object_id_${__OOB_OBJ_TABLE[$CLASS]}"

    # Register object-name.
    __OOB_ADDR_TABLE[$CLASS]="${__OOB_ADDR_TABLE[$CLASS]-}:$OBJ_NAME:"


    # Create new object.
    eval new_metaobject $OBJ_NAME $CLASS $VARNAME \"\${$CLASS[@]}\"

    # Call constructor.
    [[ $(type -t $OBJ_NAME.__new__) == function ]] && $OBJ_NAME.__new__ "$@"
}


# Deletes All references to the object
# and calls the destructor if it exists.

# Arguments:
#    * A reference to an object
delete()
{
    local CLASSNAME=$(echo $1|sed -r 's/_Object_id_[0-9]+$//')

    __OOB_ADDR_TABLE[$CLASSNAME]=$(echo "${__OOB_ADDR_TABLE[$CLASSNAME]}"|sed -r "s/:$1://")

    if [[ -z ${__OOB_ADDR_TABLE[$CLASSNAME]} ]]; then
        unset __OOB_ADDR_TABLE[$CLASSNAME]
    fi

    # Check for destructor and call it if one is existent.
    [[ $(type -t $1.__delete__) == function ]] && $1.__delete__
}


# Deletes all references to the objects of all or
# specific classes.

# Arguments:
#    + (optional) Classnames ...
delete_all()
{
    local i
    local j

    if [[ -z ${1-} ]]; then
        # Loop through all registered objects and delete them
        for i in "${__OOB_ADDR_TABLE[@]-}"; do
            local a=$(echo "$i"| \
                awk 'BEGIN { RS = ":+" } /^.+$/ {print $1" "}')

            for j in $a; do
                delete $j
            done
        done
    else
        for i; do
            local str=${__OOB_ADDR_TABLE[$i]}
            local a=$(echo "$str"| \
                awk 'BEGIN { RS = ":+" } /^.+$/ {print $1" "}')

            for j in $a; do
                delete $j
            done
        done
    fi
}
