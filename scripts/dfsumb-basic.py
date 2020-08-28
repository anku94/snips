#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import shutil
import sys

commons = {
    'CMAKE_BUILD_TYPE': 'Debug',
}

targets = {
    'deltafs-common': {
        'git': {'url': 'https://github.com/pdlfs/pdlfs-common.git', 'tag': 'v19.8'},
        'cmake': {
            'BUILD_SHARED_LIBS': 'ON',
            'BUILD_TESTS': 'OFF',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
            'PDLFS_COMMON_DEFINES': 'DELTAFS',
            'PDLFS_COMMON_LIBNAME': 'deltafs-common',
            'PDLFS_DFS_COMMON': 'ON',
            'PDLFS_EXAMPLES': 'OFF',
            'PDLFS_GFLAGS': 'ON',
            'PDLFS_GLOG': 'ON',
            'PDLFS_MARGO_RPC': 'OFF',
            'PDLFS_MERCURY_RPC': 'OFF',
            'PDLFS_RADOS': 'OFF',
            'PDLFS_SILT_ECT': 'OFF',
            'PDLFS_SNAPPY': 'OFF',
            'PDLFS_TOOLS': 'OFF',
        },
        'deps': ['mercury']
    },
    'deltafs-nexus': {
        'git': {'url': 'https://github.com/pdlfs/deltafs-nexus.git', 'tag': 'v1.19'},
        'cmake': {
            'BUILD_SHARED_LIBS': 'ON',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
        },
        'deps': ['mercury', 'mercury-progressor']
    },
    'deltafs': {
        'git': {'url': 'https://github.com/pdlfs/deltafs.git', 'tag': 'v2019.7'},
        'cmake': {
            'BUILD_SHARED_LIBS': 'ON',
            'BUILD_TESTS': 'OFF',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
            'DELTAFS_BENCHMARKS': 'ON',
            'DELTAFS_COMMON_INTREE': 'OFF',
            'DELTAFS_MPI': 'ON',
            'PDLFS_GFLAGS': 'ON',
            'PDLFS_GLOG': 'ON',
            'PDLFS_MARGO_RPC': 'OFF',
            'PDLFS_MERCURY_RPC': 'OFF',
            'PDLFS_RADOS': 'OFF',
            'PDLFS_SNAPPY': 'OFF',
        },
        'deps': ['mercury', 'deltafs-common']
    },
    'deltafs-shuffle': {
        'git': {'url': 'https://github.com/pdlfs/deltafs-shuffle.git', 'tag': 'bba0a2f6'},
        'cmake': {
            'BUILD_SHARED_LIBS': 'ON',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
        },
        'deps': ['mercury', 'mercury-progressor', 'deltafs-nexus']
    },
    'deltafs-vpic-preload': {
        'git': {'url': 'https://github.com/pdlfs/deltafs-vpic-preload.git', 'tag': 'v1.86'},
        'cmake': {
            'BUILD_TOOLS': 'ON',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
            'PRELOAD_BLKID': 'OFF',
            'PRELOAD_CH_PLACEMENT': 'OFF',
            'PRELOAD_NUMA': 'OFF',
            'PRELOAD_PAPI': 'OFF',
        },
        'deps': ['mercury', 'mssg', 'mercury-progressor', 'deltafs-common', 'deltafs-nexus', 'deltafs-shuffle', 'deltafs']
    },
    'mercury': {
        'git': {'url': 'https://github.com/mercury-hpc/mercury.git', 'tag': '41caa143'},
        'cmake': {
            'BUILD_DOCUMENTATION': 'OFF',
            'BUILD_EXAMPLES': 'OFF',
            'BUILD_SHARED_LIBS': 'ON',
            'BUILD_TESTING': 'OFF',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
            'NA_USE_BMI': 'OFF',
            'NA_USE_CCI': 'OFF',
            'NA_USE_MPI': 'OFF',
            'NA_USE_OFI': 'OFF',
            'NA_USE_SM': 'ON',
        },
        'deps': []
    },
    'mercury-progressor': {
        'git': {'url': 'https://github.com/pdlfs/mercury-progressor.git', 'tag': '89c47dc8'},
        'cmake': {
            'BUILD_SHARED_LIBS': 'ON',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
        },
        'deps': ['mercury']
    },
    'mssg': {
        'git': {'url': 'https://github.com/pdlfs/mssg.git', 'tag': 'v1.4'},
        'cmake': {
            'BUILD_SHARED_LIBS': 'ON',
            'CMAKE_BUILD_TYPE': commons['CMAKE_BUILD_TYPE'],
        },
        'deps': ['mercury']
    },
}


class Target:
    def __init__(self, dir_prefix: str, config: dict):
        self.dir_prefix = Path(dir_prefix).expanduser()
        self.config = config

        self.install_prefix = self.dir_prefix / 'install'

        self.repo_path = self.dir_prefix / self.get_repo_dirname()
        self.build_path = self.repo_path / 'build'

        self.dry_run = False

    def get_deps(self):
        return self.config['deps']

    def get_repo_dirname(self):
        dirname = Path(self.config['git']['url']).name
        if dirname.endswith('.git'):
            dirname = dirname[:-4]

        return dirname

    def get_cmake_flags(self):
        cmake_props = self.config['cmake']

        cmake_props['CMAKE_INSTALL_PREFIX'] = self.install_prefix.as_posix()

        for dep in self.config['deps']:
            cmake_props[dep + '_DIR'] = self.install_prefix / \
                'share' / 'cmake' / dep

        cmake_props_str = ' '.join(
            map(lambda x: '-D{0}={1}'.format(x[0], x[1]), cmake_props.items()))

        return cmake_props_str

    def checkout(self):
        if not self.dir_prefix.exists():
            self.dir_prefix.mkdir()

        gitconf = self.config['git']

        cmd = "cd {0}; git clone {1}; cd {2}; git submodule update --init --recursive; git checkout {3}".format(
            self.dir_prefix.as_posix(),
            gitconf['url'],
            self.repo_path.as_posix(),
            gitconf['tag'])

        print(cmd)
        if not self.dry_run:
            os.system(cmd)

        return

    def make(self):
        if not self.build_path.exists():
            if not self.dry_run:
                self.build_path.mkdir()

        cmake_flags = self.get_cmake_flags()
        cmd = "cd {0}; cmake {1} .. ; make -j; make install".format(
            self.build_path.as_posix(),
            cmake_flags
        )
        print(cmd)
        if not self.dry_run:
            os.system(cmd)

    def build(self):
        self.checkout()
        self.make()
        return


class RecursiveBuilder:
    def __init__(self, prefix_path: str, target_configs):
        self.targets = {}
        self.targets_built = []

        pref_path = Path(prefix_path).expanduser()
        if pref_path.exists():
            shutil.rmtree(pref_path)

        pref_path.mkdir()

        for target_name, target_config in target_configs.items():
            self.targets[target_name] = Target(prefix_path, target_config)

        print(self.targets)

    def build(self, target_name: str):
        print(target_name)
        if target_name not in self.targets:
            raise Exception("Unknown target")

        if target_name in self.targets_built:
            return

        target = self.targets[target_name]
        print(target_name, target.get_deps())

        for dep in target.get_deps():
            if dep not in self.targets_built:
                self.build(dep)
                self.targets_built.append(dep)

        target.build()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='DeltaFS Umbrella, basic',
        description='''
                Automatically install a minimal DeltaFS umbrella stack, with most things turned off.
            ''',
        epilog='''
                Dependencies that need to be pre-installed: glog, gflags, gtest, mpich (or any other MPI lib)
            ''')

    parser.add_argument('-p', '--prefix_path', type=str,
                        help='Clone/install everything in this path (dir will be created if it doesn\'t exist)')
    options = parser.parse_args()

    if not options.prefix_path:
        parser.print_help()
        sys.exit(0)

    verify = input('Downloading everything to {0}. Proceed? (Y/n) ').format(options.prefix_path)
    if verify and verify[0] == 'n':
        sys.exit(0)

    rb = RecursiveBuilder(options.prefix_path, targets)
    rb.build('deltafs-vpic-preload')
