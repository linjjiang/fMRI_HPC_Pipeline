# HPC Pipeline for fMRI Analysis

A High Performance Computing (HPC) Pipeline for fMRI Analysis.

## Description

This pipeline consists of a set of bash, Python and MATLAB scripts for fMRI Analysis in a Linux HPC environment from scratch.

The pipeline does the following:
1. prepare_data, including making subject lists and extracting task designs.
2. BIDS_conversion: convert raw DICOM data to BIDS format
3. fMRIPrep_preprocessing: preprocessing BIDS using state-of-the-art fMRIPrep pipeline.
4. timeseries_extraction: extracting timeseries from specific ROIs and task epochs with careful data denoising after preprocessing. The extracted BOLD timeseries are ready to be fed into ML pipelines for further analysis.

## Getting Started

### Dependencies

* Linux
* Python 3.13 with Numpy, Pandas, Scipy, NiBabel, Nilearn, dcm2niix (mostly for timeseries extraction)
* MATLAB R2019b or higher (mostly for behavioral design extraction)
* bids-validator 1.15.0

### Installing

To be updated...

### Executing program

To be updated...

## Help


## Authors

Linjing Jiang
[@linjjiang](https://github.com/linjjiang)

## Version History

* 0.1
    * Initial Release

## To-do lists

* Update installation and execution instructions

## License

This project is licensed under the MIT License - see the LICENSE.md file for details

## Acknowledgments

* [dcm2niix](https://github.com/rordenlab/dcm2niix)
* [bids-validator](https://pypi.org/project/bids-validator/)
* [fMRIPrep](https://fmriprep.org/en/stable/index.html)