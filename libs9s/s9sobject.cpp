/*
 * Severalnines Tools
 * Copyright (C) 2018  Severalnines AB
 *
 * This file is part of s9s-tools.
 *
 * s9s-tools is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * s9s-tools is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with s9s-tools. If not, see <http://www.gnu.org/licenses/>.
 */
#include "s9sobject.h"

S9sObject::S9sObject()
{
    m_properties["class_name"] = className();
}

S9sObject::S9sObject(
        const S9sObject &orig)
{
    m_properties = orig.m_properties;
}

S9sObject::S9sObject(
        const S9sVariantMap &properties) :
    m_properties(properties)
{
    if (!m_properties.contains("class_name"))
        m_properties["class_name"] = className();
}

S9sObject::~S9sObject()
{
}

S9sObject &
S9sObject::operator=(
        const S9sVariantMap &rhs)
{
    setProperties(rhs);
    
    return *this;
}

S9sString 
S9sObject::className() const 
{
    return "S9sObject"; 
}


/**
 * \returns True if a property with the given key exists.
 */
bool
S9sObject::hasProperty(
        const S9sString &key) const
{
    return m_properties.contains(key);
}

/**
 * \returns The value of the property with the given name or the empty
 *   S9sVariant object if the property is not set.
 */
S9sVariant
S9sObject::property(
        const S9sString &name) const
{
    if (m_properties.contains(name))
        return m_properties.at(name);

    return S9sVariant();
}

/**
 * \param name The name of the property to set.
 * \param value The value of the property as a string.
 *
 * This function will investigate the value represented as a string. If it looks
 * like a boolean value (e.g. "true") then it will be converted to a boolean
 * value, if it looks like an integer (e.g. 42) it will be converted to an
 * integer. Then the property will be set accordingly.
 */
void
S9sObject::setProperty(
        const S9sString &name,
        const S9sString &value)
{
    if (value.empty())
    {
        m_properties.erase(name);
        return;
    }

    if (value.looksBoolean())
    {
        m_properties[name] = value.toBoolean();
    } else if (value.looksInteger())
    {
        m_properties[name] = value.toInt();
    } else {
        m_properties[name] = value;
    }
}

void
S9sObject::setProperty(
        const S9sString &name,
        const bool       value)
{
    m_properties[name] = value;
}

void
S9sObject::setProperty(
        const S9sString &name,
        const int        value)
{
    m_properties[name] = value;
}


/**
 * \param properties The properties to be set as a name -> value mapping.
 *
 * Sets all the properties in one step. All the existing properties will be
 * deleted, then the new properties set.
 */
void
S9sObject::setProperties(
        const S9sVariantMap &properties)
{
    m_properties = properties;
}

const S9sVariantMap &
S9sObject::toVariantMap() const
{
    return m_properties;
}

S9sString 
S9sObject::name() const
{
    return property("alias").toString();
}

S9sString
S9sObject::name(
        const int columns) const
{
    S9sString retval = name();

    if (columns <= 0)
        return retval;

    if ((int)retval.length() > columns)
    {
        retval.resize(columns);
        retval += "…";
    }

    return retval;
}


S9sString 
S9sObject::aclString() const
{
    return property("acl").toString();
}

S9sString 
S9sObject::aclShortString() const
{
    S9sString retval = property("acl").toString();

    retval.replace("user::", "");
    retval.replace(",group::", "");
    retval.replace(",other::", "");

    return retval;
}

S9sString 
S9sObject::id() const
{
    return property("id").toString();
}

S9sString 
S9sObject::cdtPath() const
{
    return property("cdt_path").toString();
}

/**
 * \returns The user name of the user that owns this object.
 */
S9sString 
S9sObject::ownerName() const
{
    return property("owner_user_name").toString();
}

/**
 * \returns The group name of the group that owns the object.
 */
S9sString 
S9sObject::groupOwnerName() const
{
    return property("owner_group_name").toString();
}
