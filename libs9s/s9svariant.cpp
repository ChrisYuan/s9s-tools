/*
 * Severalnines Tools
 * Copyright (C) 2016  Severalnines AB
 *
 * This file is part of s9s-tools.
 *
 * s9s-tools is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * S9sTools is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with S9sTools. If not, see <http://www.gnu.org/licenses/>.
 */
#include "s9svariant.h"
#include "S9sVariantMap"
#include "S9sVariantList"

#include <errno.h>
#include <strings.h>
#include <stdlib.h>
#include <climits>
#include <cmath>
#include <limits> 

#include "S9sNode"

#define DEBUG
#include "s9sdebug.h"

const S9sVariantMap  S9sVariant::sm_emptyMap;
const S9sVariantList S9sVariant::sm_emptyList = S9sVariantList();
static const S9sNode sm_emptyNode;

#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wreturn-type"
#pragma GCC visibility push(hidden)
#endif

S9sVariant::S9sVariant(
        const S9sVariant &orig)
{
    m_type         = orig.m_type;

    switch (m_type)
    {
        case Invalid:
        case Int:
        case Ulonglong:
        case Double:
        case Bool:
            /* We don't need to copy here. */
            m_union = orig.m_union;
            break;
        
        case String:
            m_union.stringValue = new S9sString(*orig.m_union.stringValue);
            break;

        case List:
            m_union.listValue = new S9sVariantList(*orig.m_union.listValue);
            break;

        case Map:
            m_union.mapValue = new S9sVariantMap(*orig.m_union.mapValue);
            break;

        case Node:
            m_union.nodeValue = new S9sNode(*orig.m_union.nodeValue);
            break;
    }
}

S9sVariant::S9sVariant(
        const S9sNode &nodeValue) :
    m_type (Node)
{
    m_union.nodeValue = new S9sNode(nodeValue);
}

S9sVariant::S9sVariant(
        const S9sVariantMap &mapValue) :
    m_type(Map)
{
    m_union.mapValue = new S9sVariantMap(mapValue);
}

S9sVariant::S9sVariant(
        const S9sVariantList &listValue) :
    m_type(List)
{
    m_union.listValue = new S9sVariantList(listValue);
}

S9sVariant::~S9sVariant()
{
    clear();
}

/**
 * Assignment operator for the S9sVariant class that accepts an other S9sVariant
 * object as right hand side argument.
 */
S9sVariant &
S9sVariant::operator= (
        const S9sVariant &rhs)
{
    if (this == &rhs)
        return *this;

    clear();

    m_type         = rhs.m_type;
    
    switch (m_type)
    {
        case Invalid:
        case Int:
        case Ulonglong:
        case Double:
        case Bool:
            /* We don't need to copy here. */
            m_union = rhs.m_union;
            break;
        
        case String:
            m_union.stringValue = new S9sString(*rhs.m_union.stringValue);
            break;

        case List:
            m_union.listValue = new S9sVariantList(*rhs.m_union.listValue);
            break;

        case Map:
            m_union.mapValue = new S9sVariantMap(*rhs.m_union.mapValue);
            break;

        case Node:
            m_union.nodeValue = new S9sNode(*rhs.m_union.nodeValue);
            break;
    }
    
    return *this;
}

bool 
S9sVariant::operator== (
        const S9sVariant &rhs) const
{
    if (isInt() && rhs.isInt())
    {
        return toInt() == rhs.toInt();
    } else if (isULongLong() && rhs.isULongLong()) 
    {
        return toULongLong() == rhs.toULongLong();
    } else if (isDouble() && rhs.isDouble()) 
    {
        return fuzzyCompare(toDouble(), rhs.toDouble());
    } else if (isString() && rhs.isString())
    {
        return toString() == rhs.toString();
    } else if (isNumber() && rhs.isNumber())
    {
        return fuzzyCompare(toDouble(), rhs.toDouble());
    } else if (isBoolean() && rhs.isBoolean())
    {
        return toBoolean() == rhs.toBoolean();
    } else if ((isString() && !rhs.isString())
            || (!isString() && rhs.isString()))
    {
        // It seems that comparing a string with other than a string returning
        // true is rather counterintuitive. 
        return false;
    } else {
        //S9S_WARNING("TBD: (%s)%s == (%s)%s", 
        //        STR(toString()), STR(typeName()),
        //        STR(rhs.toString()), STR(rhs.typeName()));
        return false;
    }

    return false;
}

bool 
S9sVariant::operator< (
        const S9sVariant &rhs) const
{
    if (isInt() && rhs.isInt())
        return toInt() < rhs.toInt();
    else if (isULongLong() && rhs.isULongLong())
        return toULongLong() < rhs.toULongLong();
    else if (isNumber() && rhs.isNumber())
        return toDouble() < rhs.toDouble();
    else if (isString() && rhs.isString())
        return toString() < rhs.toString();

    return false;
}

S9sVariant &
S9sVariant::operator[] (
        const S9sString &index)
{
    if (m_type == Invalid)
    {
        *this = S9sVariantMap();
        return this->operator[](index);
    }

    if (m_type == Map)
    {
        return m_union.mapValue->S9sMap<
                S9sString, S9sVariant>::operator[](index);
    } 
    
    assert(false);
}

S9sString 
S9sVariant::typeName() const
{
    S9sString retval;

    switch (m_type)
    {
        case Invalid:
            retval = "invalid";
            break;

        case Int:
            retval = "int";
            break;

        case Ulonglong:
            retval = "ulonglong";
            break;

        case Double:
            retval = "double";
            break;

        case Bool:
            retval = "bool";
            break;
        
        case String:
            retval = "string";
            break;
        
        case Node:
            retval = "node";
            break;

        case List:
            retval = "list";
            break;

        case Map:
            retval = "map";
            break;
    }

    return retval;
}

const S9sNode &
S9sVariant::toNode() const
{
    switch (m_type)
    {
        case Invalid:
        case Int:
        case Ulonglong:
        case Double:
        case Bool:
        case String:
        case List:
        case Map:
            return sm_emptyNode;

        case Node:
            return *m_union.nodeValue;
    }
            
    return sm_emptyNode;
}


/**
 * \returns the reference to the S9sVariantMap held in the S9sVariant.
 */
const S9sVariantMap &
S9sVariant::toVariantMap() const
{
    switch (m_type)
    {
        case Invalid:
        case Int:
        case Ulonglong:
        case Double:
        case Bool:
        case String:
        case List:
            return sm_emptyMap;

        case Map:
            return *m_union.mapValue;

        case Node:
            return m_union.nodeValue->toVariantMap();
    }
            
    return sm_emptyMap;
}

/**
 * \returns the reference to the S9sVariantMap held in the S9sVariant.
 */
const S9sVariantList &
S9sVariant::toVariantList() const
{
    switch (m_type)
    {
        case Invalid:
        case Int:
        case Ulonglong:
        case Double:
        case Bool:
        case String:
        case Map:
        case Node:
            return sm_emptyList;

        case List:
            return *m_union.listValue;
    }
            
    return sm_emptyList;
}

/**
 * \param defaultValue the value to be returned if the variant can't be
 *   converted to an integer.
 * \returns the value in the variant converted to integer.
 *
 */
int
S9sVariant::toInt(
        const int defaultValue) const
{
    switch (m_type)
    {
        case Invalid:
            // The integer value defaults to 0 as a global int variable would.
            // You can rely on this.
            return defaultValue;

        case String:
            return toString().empty() ? defaultValue : atoi(toString().c_str());

        case Int:
            return m_union.iVal;

        case Double:
            return (int) m_union.dVal;

        case Ulonglong:
            // This is cheating, converting an ulonglong value to integer might
            // cause data loss.
            return (int) m_union.ullVal;

        case Bool:
            return m_union.bVal ? 1 : 0;

        case Map:
        case List:
        case Node:
            return defaultValue;
    }

    return defaultValue;
}

/**
 * \param defaultValue the value to be returned if the variant can't be
 *   converted to unsigned long long.
 * \returns the value in the variant converted to unsigned long long.
 *
 */
ulonglong
S9sVariant::toULongLong(
        ulonglong defaultValue) const
{
    switch (m_type)
    {
        case Invalid:
            return defaultValue;

        case Ulonglong:
            return m_union.ullVal;

        case Int:
            return (ulonglong) m_union.iVal;

        case Double:
            return (ulonglong) m_union.dVal;

        case String:
            if (toString().empty())
                return defaultValue;

            return strtoull(toString().c_str(), NULL, 0);

        case Bool:
            return m_union.bVal ? 1ull : 0ull;

        case Map:
        case List:
        case Node:
            // FIXME: This is not yet implemented.
            return defaultValue;
    }

    return defaultValue;
}

time_t
S9sVariant::toTimeT() const
{
    return toULongLong(0ull);
}


/**
 * If the value can not be converted to a double value this function will return
 * 0.0.
 */
double
S9sVariant::toDouble(
        const double defaultValue) const
{
    double retval = defaultValue;

    switch (m_type)
    {
        case Map:
        case List:
        case Invalid:
        case Node:
            // The default value is already there.
            break;

        case Double:
            retval = m_union.dVal;
            break;

        case Int:
            retval = double(m_union.iVal);
            break;

        case Ulonglong:
            retval = double(m_union.ullVal);
            break;

        case String:
            errno = 0;
            retval = strtod(STR(toString()), NULL);

            if (errno != 0)
                retval = defaultValue;

            break;

        case Bool:
            retval = m_union.bVal ? 1.0 : 0.0;
            break;
    }

    return retval;
}

/**
 * \param defaultValue the value that shall be returned if the variant can't be
 *   converted to a boolean.
 * \returns the value from the variant converted to a boolean.
 *
 * This method recognizes all the usual strings used to denote boolean values
 * like "yes", "true", "T", "on".
 */
bool
S9sVariant::toBoolean(
        const bool defaultValue) const
{
    switch (m_type)
    {
        case Invalid:
            return defaultValue;

        case Bool:
            return m_union.bVal;

        case String:
            {
                std::string trimmed = toString().trim();

                if (trimmed.empty())
                    return defaultValue;
        
                if (!strcasecmp(trimmed.c_str(), "yes") ||
                    !strcasecmp(trimmed.c_str(), "true") ||
                    !strcasecmp(trimmed.c_str(), "on") ||
                    !strcasecmp(trimmed.c_str(), "t"))
                {
                    return true;
                }

                if (!strcasecmp(trimmed.c_str(), "no") ||
                    !strcasecmp(trimmed.c_str(), "false") ||
                    !strcasecmp(trimmed.c_str(), "off") ||
                    !strcasecmp(trimmed.c_str(), "f"))
                {
                    return false;
                }

                if (atoi(trimmed.c_str()) != 0) 
                    return true;
                else 
                    return false;
            }
            break;

        case Int:
            return m_union.iVal != 0;

        case Double:
            return m_union.dVal != 0.0;

        case Ulonglong:
            return m_union.ullVal != 0ull;

        case Map:
        case List:
        case Node:
            return defaultValue;
    }

    return defaultValue;
}


/**
 * This is the simplest method of the toString() family. It returns a short, one
 * line version of the value that is not necesserily a full representation, but
 * it is excellent to be shown in messages, logs, debug strings.
 */
S9sString
S9sVariant::toString() const
{
    S9sString retval;

    if (m_type == String)
    {
        retval = *m_union.stringValue;
    } else if (m_type == Invalid)
    {
        // Nothing to do, empty string...
        ;
    } else if (m_type == Bool)
    {
        retval = m_union.bVal ? "true" : "false";
    } else if (m_type == Int)
    {
        retval.sprintf("%d", m_union.iVal);
    } else if (m_type == Ulonglong)
    {
        retval.sprintf("%llu", m_union.ullVal);
    } else if (m_type == Double)
    {
        retval.sprintf("%g", m_union.dVal);
    } else if (m_type == Map)
    {
        //CmonJSonMessage map = toVariantMap();
        //retval = map.toString();
    #if 0
    } else if (m_type == List)
    {
        const CmonVariantList &list = toVariantList();

        retval = "{";
        for (uint idx = 0; idx < list.size(); ++idx)
        {
            const CmonVariant &item = list[idx];
            if (idx > 0)
                retval += ", ";

            retval += item.toString();
        }
        retval += "}";
    } else if (m_type == Array)
    {
        // Converting an array into a string. This is only used in 
        // spreadsheets so we are adding some quotes too.
        CmonVariantArray array = toVariantArray();
        for (uint column = 0; column < array.columns(); ++column)
        {
            if (!retval.empty())
                retval += "; ";

            // Limiting the string length for speed. 
            if (column > 5)
            {
                //CMON_WARNING("TOO MANY COLUMNS");
                retval += "...";
                break;
            }

            for (uint row = 0; row < array.rows(); ++row)
            {
                CMON_DEBUG("%2d, %2d: '%s'", 
                        column, row, 
                        STR(array.at(column, row).toString()));

                if (!retval.empty() && !retval.endsWith("; "))
                    retval += ", ";

                // Limiting the string length for speed.
                if (row > 5)
                {
                    //CMON_WARNING("TOO MANY ROWS");
                    retval += "...";
                    break;
                }

                if (array.at(column, row).isString())
                    retval = retval + "\"" +
                        array.at(column, row).toString() + "\"";
                else
                    retval = retval + array.at(column, row).toString();
            }
        }

        retval = "{" + retval + "}";
    #endif
    } else {
        //CMON_WARNING("Not implemented for %s", STR(typeName()));
    }

    return retval;
}

/**
 * Drops the value from the variant, sets its type to "Invalid" and releases all
 * resources that the variant might hold. This function is also called from the
 * destructor.
 */
void
S9sVariant::clear()
{
    switch (m_type) 
    {
        case Invalid:
        case Bool:
        case Int:
        case Ulonglong:
        case Double:
            // Nothing to do here.
            break;

        case String:
            delete m_union.stringValue;
            m_union.stringValue = NULL;
            break;

        case Map:
            delete m_union.mapValue;
            m_union.mapValue = NULL;
            break;

        case List:
            delete m_union.listValue;
            m_union.listValue = NULL;
            break;

        case Node:
            delete m_union.nodeValue;
            m_union.nodeValue = NULL;
            break;
    }

    m_type = Invalid;
}

bool 
S9sVariant::fuzzyCompare(
        const double first, 
        const double second)
{
    return std::fabs(first - second) < 
        // This is much more liberal
        // 1e-12;
        // It seems the error is usually much greater than epsilon.
        10 * std::numeric_limits<double>::epsilon();
}

