﻿using System.Runtime.InteropServices;
using UnityEngine;

namespace Possible.Vision
{
    /// <summary>
    /// Managed counterpart for iOS CGPoint.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    public struct CGPoint
    {
        public double x;
        public double y;

        public CGPoint(double x, double y)
        {
            this.x = x;
            this.y = y;
        }

        /// <summary>
        /// Converts CGPoint to Unity's Vector2 type.
        /// </summary>
        public static implicit operator Vector2(CGPoint point)
        {
            return new Vector2((float)point.x, (float)point.y);
        }
    }
}