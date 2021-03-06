/*
 * Severalnines Tools
 * Copyright (C) 2016-2018 Severalnines AB
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
#pragma once

#include "S9sString"
#include "S9sVariantMap"
#include "S9sEvent"
#include "S9sNode"
#include "S9sServer"
#include "S9sCluster"
#include "S9sJob"
#include "S9sMutex"
#include "S9sThread"
#include "S9sFile"

#define S9S_KEY_DOWN      0x425b1b
#define S9S_KEY_UP        0x415b1b
#define S9S_KEY_RIGHT     0x435b1b
#define S9S_KEY_LEFT      0x445b1b
#define S9S_KEY_PGUP      0x7e355b1b
#define S9S_KEY_PGDN      0x7e365b1b
#define S9S_KEY_ENTER     0x0d
#define S9S_KEY_BACKSPACE 0x7f
#define S9S_KEY_DELETE    0x7e335b1b
#define S9S_KEY_HOME      0x00485b1b
#define S9S_KEY_END       0x00465b1b

/**
 * A UI screen that can be used as a parent class for views continuously
 * refreshed on the terminal screen.
 */
class S9sDisplay : public S9sThread
{
    public:
        S9sDisplay(bool interactive = true, bool rawTerminal = true);
        virtual ~S9sDisplay();

        bool setOutputFileName(const S9sString &fileName);
        bool setInputFileName(const S9sString &fileName);
        bool hasInputFile() const;

        int lastKeyCode() const;

        int columns() const;
        int rows() const;
        void gotoXy(int x, int y);

    protected:
        virtual int exec();
        
    protected:
        virtual void processKey(int key) = 0;
        virtual void processButton(uint button, uint x, uint y);
        virtual bool refreshScreen() = 0;

        void startScreen();
        
        virtual void printHeader() = 0;
        virtual void printFooter() = 0;

        void printMiddle(const S9sString text);
        void printNewLine();
        
        char rotatingCharacter() const;

    private:
        void setConioTerminalMode(
                bool interactive,
                bool rawTerminal);

        int kbhit();

    protected:
        bool                         m_rawTerminal;
        bool                         m_interactive;
        S9sMutex                     m_mutex;
        int                          m_refreshCounter;
        
        union {
            unsigned char  inputBuffer[6];
            int   lastKeyCode;
        } m_lastKeyCode;

        int                          m_columns;
        int                          m_rows;
        int                          m_lineCounter;
        S9sFile                      m_outputFile;
        S9sString                    m_outputFileName;
        S9sFile                      m_inputFile;
        S9sString                    m_inputFileName;
        int                          m_lastButton;
        int                          m_lastX;
        int                          m_lastY;
        bool                         m_isStopped;

};
