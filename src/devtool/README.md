# COMET DevTool Software Installation And Usage

## Setup
To get devtool working (on WSL2 as an example environment), make sure the following tasks have been completed:

* Install the Python3 venv utilities: `sudo apt install python3.xx-venv`
* Create a virtual environment to use DevTool with: `python3 -m venv ~/.venv/devtool`
* Activate the virtual environment: `source ~/.venv/devtool/bin/activate`
* Install the required Python modules into the virtual env: `pip install -r requirements.txt`
* Install libusb1: `sudo apt install libusb-1.0-0`
* Add your user to the group that allows access to serial ports: `sudo usermod -aG dialout <username>`
* Create udev rules in `/etc/udev/rules.d/99-comet-devtool.rules`:

```
SUBSYSTEM=="usb", ATTRS{idVendor}=="04d8", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", MODE="0666", GROUP="plugdev"
```

You may need to restart your machine or WSL instance at this point, but afterwards, try running `./devtool.py init --list` to see if your devtool is listed, then configure the COMET_DEV_TOOL_SN environment variable accordingly.

## Usage
The COMET DevTool allows a COMETbus system to be remotely controlled in a variety of scriptable ways. Obtain help on the available functions by running `./devtool.py --help`.
