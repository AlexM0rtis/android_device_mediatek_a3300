# mt6582 platform boardconfig

# Use the non-open-source part, if present
-include vendor/mediatek/mt6582/BoardConfigVendor.mk

# Use the common part
include device/mediatek/common/BoardConfig.mk

TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a7
TARGET_CPU_SMP := true
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
ARCH_ARM_HAVE_TLS_REGISTER := true
TARGET_BOARD_PLATFORM := mt6582
MTK_PLATFORM := MT6582
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_NO_FACTORYIMAGE:=true
KERNELRELEASE := 3.4

# display related
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3
TARGET_FORCE_HWC_FOR_VIRTUAL_DISPLAYS := true
TARGET_RUNNING_WITHOUT_SYNC_FRAMEWORK := true
MTK_HWC_SUPPORT := yes
MTK_HWC_VERSION := 1.3.0

TARGET_RECOVERY_PIXEL_FORMAT := ABGR_8888

# For MM thread priority
ifneq ($(MTK_BASIC_PACKAGE), yes)
MTK_USE_RT_PRIORITY := yes
endif

BOARD_CONNECTIVITY_VENDOR := MediaTek
BOARD_USES_MTK_AUDIO := true

ifeq ($(MTK_AGPS_APP), yes)
   BOARD_AGPS_SUPL_LIBRARIES := true
else
   BOARD_AGPS_SUPL_LIBRARIES := false
endif

ifeq ($(MTK_GPS_SUPPORT), yes)
  BOARD_GPS_LIBRARIES := true
else
  BOARD_GPS_LIBRARIES := false
endif

ifeq ($(strip $(BOARD_CONNECTIVITY_VENDOR)), MediaTek)

BOARD_CONNECTIVITY_MODULE := conn_soc 
BOARD_MEDIATEK_USES_GPS := true
#ifeq ($(strip $(BOARD_CONNECTIVITY_MODULE)), soc_conn)
#combo_config := hardware/mediatek/config/$(strip $(BOARD_CONNECTIVITY_MODULE))/board_config.mk
#include $(combo_config)
#endif

endif

ifeq ($(MTK_WLAN_SUPPORT), yes)
WPA_SUPPLICANT_VERSION := VER_0_8_X_MTK
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_mt66xx
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_mt66xx
WIFI_DRIVER_FW_PATH_PARAM:="/dev/wmtWifi"
WIFI_DRIVER_FW_PATH_STA:=STA
WIFI_DRIVER_FW_PATH_AP:=AP
WIFI_DRIVER_FW_PATH_P2P:=P2P
ifneq ($(strip $(MTK_BSP_PACKAGE)),yes)
MTK_WIFI_CHINESE_SSID := yes
ifeq ($(MTK_EAP_SIM_AKA), yes)
CONFIG_RILD_MULTI_SIM := yes
endif
endif
ifeq ($(strip $(MTK_BSP_PACKAGE)),yes)
MTK_WIFI_GET_IMSI_FROM_PROPERTY := yes
endif
endif

# mkbootimg header, which is used in LK
BOARD_KERNEL_BASE = 0x80000000
BOARD_KERNEL_OFFSET = 0x00008000
BOARD_RAMDISK_OFFSET = 0x04000000
BOARD_TAGS_OFFSET = 0x00000100

# Add MTK compile options to wrap MTK's modifications on AOSP.
COMMON_GLOBAL_CFLAGS += -DMTK_AOSP_ENHANCEMENT
COMMON_GLOBAL_CPPFLAGS += -DMTK_AOSP_ENHANCEMENT
