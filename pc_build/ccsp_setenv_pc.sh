
#######################################################################
#   Copyright [2014] [Cisco Systems, Inc.]
# 
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#######################################################################


export CcspArch=pc
export CcspBoard=pc
export CcspCustomer=

export Board=pc
export BUILD_DBG=0
export CROSS_COMPILE=
export OEBASE=

CCSP_ROOT_DIR=$PWD
export CCSP_ROOT_DIR=$CCSP_ROOT_DIR
export CCSP_COMMON_DIR=$CCSP_ROOT_DIR/CcspCommonLibrary
export CCSP_OUT_DIR=$CCSP_ROOT_DIR/Out/$Board


# ******************* Point to the OpenSource ROOT folder ***********************************
export CCSP_OPENSOURCE_ROOT=${HOME}/workspace/opensource_install
