from setuptools import find_packages, setup
import pathlib

here = pathlib.Path(__file__).parent.resolve()


# Get the long description from the README file
long_description = (here / 'README.md').read_text(encoding='utf-8')

setup(
    name='site1_api',
    version='0.0.1-alpha.1',
    description="API for example site1",
    long_description=long_description,
    long_description_content_type='text/markdown',
    package_dir={'': 'src'},
    packages=find_packages(where='src'),
    include_package_data=True,
    python_requires='>=3.8, <4',
    zip_safe=False,
    install_requires=[
        'flask',
        'gevent',
    ],
    extras_require={  # Optional
        # 'dev': ['check-manifest'],
        'test': ['pytest', 'coverage'],
    },
    entry_points={
        "console_scripts": [
            "start=site1_api.script:main",
        ]
    }
)
