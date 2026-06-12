"""Immich to Frigate training set curator.

AI-powered tool to extract high-quality, diverse training images from your
Immich library for Frigate's Face Recognition (ArcFace) and Object/State
Classification models.
"""

from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("winnow")
except PackageNotFoundError:
    __version__ = "unknown"
