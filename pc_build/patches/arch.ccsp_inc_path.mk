##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2015 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################
#######################################################################
#   Copyright [2014] [Cisco Systems, Inc.]
# 
#   Licensed under the Apache License, Version 2.0 (the \"License\");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an \"AS IS\" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#######################################################################

#
# this file provides INCPATH definition for bisga usermode include directories
#

INCBASE := $(CCSP_COMMON_DIR)/source


# put all include dirs here to save some work on TARGET
# The following is for the util api
INCPATH += \
$(INCBASE)/debug_api/include \
$(INCBASE)/debug_api/include/linux \
$(INCBASE)/cosa/include \
$(INCBASE)/cosa/include/linux \
$(INCBASE)/ccsp/custom \
$(INCBASE)/util_api/web/include \
$(INCBASE)/util_api/stun/include \
$(INCBASE)/util_api/tls/include \
$(INCBASE)/util_api/asn.1/include \
$(INCBASE)/util_api/http/include \
$(INCBASE)/util_api/http/utilities/include \
$(INCBASE)/util_api/http/utilities/HttpSimpleMsgParser \

INCPATH += \
$(INCBASE)/util_api/ansc/AnscUtilBox \
$(INCBASE)/util_api/ansc/include \
$(INCBASE)/util_api/ansc/AnscSimpleProxyTcp \
$(INCBASE)/util_api/include/linux \
$(INCBASE)/util_api/ansc/AnscCrypto \
$(INCBASE)/util_api/ansc/AnscCrypto/crypto_bak/include \
$(INCBASE)/util_api/slap/components/SlapVarConverter/ \

INCPATH += \
$(INCBASE)/ccsp/include \
$(INCBASE)/cosa/package/system/include \
$(INCBASE)/ccsp/PersistentStorage/include

INCPATH += \
$(CCSP_OPENSOURCE_ROOT)/include/dbus-1.0 \
$(CCSP_OPENSOURCE_ROOT)/lib/dbus-1.0/include \
$(CCSP_OPENSOURCE_ROOT)/include/net-snmp \
$(INCBASE)/ccsp/components/common/MessageBusHelper/include \
$(INCBASE)/ccsp/components/common/PoamIrepFolder \
$(INCBASE)/cosa/package/slap/include \

INCPATH += \
$(INCBASE)/cosa/package/slap/services/dslh/include \
$(INCBASE)/cosa/package/slap/services/bmc2/include \
$(INCBASE)/cosa/package/cli/include \
$(INCBASE)/cosa/package/bmc2/include \
$(INCBASE)/cosa/package/bmw2/bwrm/include \
$(INCBASE)/cosa/package/bmw2/beep/include \
$(INCBASE)/cosa/package/bmw2/bree/include \
$(INCBASE)/cosa/package/bmw2/bwsp/include \
$(INCBASE)/cosa/package/bmw2/include \
$(INCBASE)/cosa/utilities/include \
$(INCBASE)/cosa/package/slap/include \

INCPATH += $(INCBASE)/ccsp/components/include

ifeq ($(ANDROID_ARM),y) 
INCPATH += $(ANDROID_NDK_DIR)/platforms/android-8/arch-arm/usr/include 
endif
