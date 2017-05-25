/* 
 * Copyright (C) 2011-2017 severalnines.com
 */
#pragma once

#include "S9sGraph"
#include "S9sNode"

/**
 * A graph that understands Cmon Statistical data.
 */
class S9sCmonGraph : public S9sGraph
{
    public:
        enum GraphTemplate
        {
            Unknown,
            LoadAverage,
            CpuGhz,
            CpuTemp,
            SqlStatements,
            SqlConnections,
            MemUtil,
            MemFree,
        };

        S9sCmonGraph();
        virtual ~S9sCmonGraph();
        
        bool setGraphType(S9sCmonGraph::GraphTemplate type);
        bool setGraphType(const S9sString &graphType);

        void setNode(const S9sNode &node);

        virtual void appendValue(S9sVariant value);
        virtual void realize();
        
    private:
        GraphTemplate  m_graphType;
        S9sVariantList m_values;
        S9sNode        m_node;
};