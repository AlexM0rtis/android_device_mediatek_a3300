# Use the non-open-source part, if present
-include vendor/lcsh/lcsh6582_w_l/BoardConfigVendor.mk

# Use the 6582 common part
include device/mediatek/mt6582/BoardConfig.mk

#Config partition size
-include $(MTK_PTGEN_OUT)/partition_size.mk
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_FLASH_BLOCK_SIZE := 4096

include device/lcsh/$(MTK_TARGET_PROJECT)/ProjectConfig.mk

MTK_INTERNAL_CDEFS := $(foreach t,$(AUTO_ADD_GLOBAL_DEFINE_BY_NAME),$(if $(filter-out no NO none NONE false FALSE,$($(t))),-D$(t))) 
MTK_INTERNAL_CDEFS += $(foreach t,$(AUTO_ADD_GLOBAL_DEFINE_BY_VALUE),$(if $(filter-out no NO none NONE false FALSE,$($(t))),$(foreach v,$(shell echo $($(t)) | tr '[a-z]' '[A-Z]'),-D$(v)))) 
MTK_INTERNAL_CDEFS += $(foreach t,$(AUTO_ADD_GLOBAL_DEFINE_BY_NAME_VALUE),$(if $(filter-out no NO none NONE false FALSE,$($(t))),-D$(t)=\"$($(t))\")) 

COMMON_GLOBAL_CFLAGS += $(MTK_INTERNAL_CDEFS)
COMMON_GLOBAL_CPPFLAGS += $(MTK_INTERNAL_CDEFS)

BOARD_MTK_BOOTIMG_SIZE_KB := 13485760 
#6144
BOARD_MTK_RECOVERY_SIZE_KB := 13485760
#6144

ifeq ($(strip $(MTK_IPOH_SUPPORT)), yes)
# Guarantee cache partition size: 240MB.
BOARD_MTK_ANDROID_SIZE_KB :=819200
BOARD_MTK_CACHE_SIZE_KB :=245760
BOARD_MTK_USRDATA_SIZE_KB :=931840
endif

