#!/usr/bin/env python

from setuptools import setup, find_packages

DESCRIPTION = 'REST Api for the STM Fish Fry Website'
LONG_DESCRIPTION = open('README.md').read()

setup(
    name='stm_fish_fry',
    version='0.1',
    description=DESCRIPTION,
    long_description=LONG_DESCRIPTION,
    author='Brian Mego',
    author_email='brianmego@gmail.com',
    url='',
    platforms=["any"],
    packages=find_packages()
)
