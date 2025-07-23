#!/usr/bin/env python3
"""
Haxe/Lime 多平台构建脚本
支持平台: windows, mac, linux, android, ios, html5, flash
用法: 
  python build.py [平台] [选项]
示例:
  python build.py windows
  python build.py android -debug
  python build.py all -clean
"""

import subprocess
import sys
import os
from enum import Enum
import argparse
import time

class Platform(Enum):
    WINDOWS = "windows"
    MAC = "mac"
    LINUX = "linux"
    ANDROID = "android"
    IOS = "ios"
    HTML5 = "html5"
    FLASH = "flash"
    ALL = "all"

    @classmethod
    def list(cls):
        return [p.value for p in cls]

class BuildSystem:
    def __init__(self):
        self.PLATFORM_COLORS = {
            Platform.WINDOWS: "\033[94m",  # 蓝色
            Platform.MAC: "\033[95m",       # 紫色
            Platform.LINUX: "\033[92m",     # 绿色
            Platform.ANDROID: "\033[93m",   # 黄色
            Platform.IOS: "\033[96m",       # 青色
            Platform.HTML5: "\033[91m",     # 红色
            Platform.FLASH: "\033[90m",     # 灰色
        }
        self.RESET_COLOR = "\033[0m"
        self.SUCCESS_COLOR = "\033[1;32m"  # 亮绿色
        self.ERROR_COLOR = "\033[1;31m"    # 亮红色

    def print_banner(self):
        """显示美观的标题"""
        print("\n" + "=" * 60)
        print(f"{'Haxe/Lime 多平台构建系统':^60}")
        print("=" * 60)
        print(f"{'支持平台:':<15}{', '.join(Platform.list())}")
        print(f"{'常用命令:':<15}python build.py [平台] [选项]")
        print("=" * 60 + "\n")

    def run_command(self, platform, options=None):
        """执行构建命令"""
        if options is None:
            options = []
        
        platform_color = self.PLATFORM_COLORS.get(platform, self.RESET_COLOR)
        print(f"{platform_color}▶ 开始构建 {platform.value} 平台...{self.RESET_COLOR}")
        
        start_time = time.time()
        cmd = ["haxelib", "run", "lime", "build", platform.value] + options
        
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            # 实时输出带颜色
            for line in process.stdout:
                sys.stdout.write(f"{platform_color}{line}{self.RESET_COLOR}")
                sys.stdout.flush()
            
            process.wait()
            elapsed_time = time.time() - start_time
            
            if process.returncode == 0:
                print(f"{self.SUCCESS_COLOR}✓ {platform.value} 构建成功! "
                      f"(耗时: {elapsed_time:.2f}s){self.RESET_COLOR}\n")
                return True
            else:
                print(f"{self.ERROR_COLOR}✗ {platform.value} 构建失败! "
                      f"(耗时: {elapsed_time:.2f}s){self.RESET_COLOR}\n")
                return False
        
        except Exception as e:
            print(f"{self.ERROR_COLOR}执行错误: {e}{self.RESET_COLOR}\n")
            return False

    def build_platforms(self, platforms, options=None):
        """构建多个平台"""
        success_count = 0
        total_platforms = len(platforms)
        
        for idx, platform in enumerate(platforms, 1):
            print(f"[{idx}/{total_platforms}] ", end="")
            if self.run_command(platform, options):
                success_count += 1
        
        print(f"\n{self.SUCCESS_COLOR}构建完成: "
              f"{success_count} 个平台成功, "
              f"{total_platforms - success_count} 个平台失败{self.RESET_COLOR}")
        
        return success_count == total_platforms

def main():
    parser = argparse.ArgumentParser(
        description="Haxe/Lime 多平台构建脚本",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "platform",
        nargs="?",
        default="all",
        choices=Platform.list() + ["all"],
        help="目标平台 (默认: all)"
    )
    parser.add_argument(
        "-debug", 
        action="store_true",
        help="调试模式构建"
    )
    parser.add_argument(
        "-release", 
        action="store_true",
        help="发布模式构建"
    )
    parser.add_argument(
        "-final", 
        action="store_true",
        help="最终发布构建"
    )
    parser.add_argument(
        "-clean", 
        action="store_true",
        help="清理构建缓存"
    )
    
    args = parser.parse_args()
    builder = BuildSystem()
    builder.print_banner()
    
    # 构建选项
    build_options = []
    if args.debug: build_options.append("-debug")
    if args.release: build_options.append("-release")
    if args.final: build_options.append("-final")
    if args.clean: build_options.append("-clean")
    
    # 确定目标平台
    if args.platform == "all":
        target_platforms = [p for p in Platform if p != Platform.ALL]
    else:
        target_platforms = [Platform(args.platform)]
    
    # 执行构建
    success = builder.build_platforms(target_platforms, build_options)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()