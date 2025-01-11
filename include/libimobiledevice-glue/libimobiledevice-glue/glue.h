/*
 * glue.h
 * Common definitions
 *
 * Copyright (c) 2024 Nikias Bassen, All Rights Reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef __GLUE_H
#define __GLUE_H

#ifndef LIMD_GLUE_API
  #ifdef LIMD_GLUE_STATIC
    #define LIMD_GLUE_API
  #elif defined(_WIN32)
    #define LIMD_GLUE_API __declspec(dllimport)
  #else
    #define LIMD_GLUE_API
  #endif
#endif

LIMD_GLUE_API const char* libimobiledevice_glue_version();

#endif
