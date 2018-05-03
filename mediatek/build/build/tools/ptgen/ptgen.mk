include device/mediatek/$(PROJECT)/ProjectConfig.mk

export MTK_LCA_SUPPORT
export MTK_NAND_PAGE_SIZE
export MTK_EMMC_SUPPORT
export MTK_LDVT_SUPPORT
export MTK_EMMC_SUPPORT_OTP
export MTK_SHARED_SDCARD
export MTK_DRM_KEY_MNG_SUPPORT
export MTK_IN_HOUSE_TEE_SUPPORT
export TARGET_BUILD_VARIANT
export MTK_CIP_SUPPORT
export MTK_NAND_UBIFS_SUPPORT
export PL_MODE
export MTK_YAML_SCATTER_FILE_SUPPORT
export FULL_PROJECT
export MTK_SPI_NAND_SUPPORT
export MTK_FAT_ON_NAND
export MTK_COMBO_NAND_SUPPORT
export TRUSTONIC_TEE_SUPPORT
export MTK_DRM_KEY_MNG_SUPPORT
export MTK_PERSIST_PARTITION_SUPPORT
export MTK_EMMC_POWER_ON_WP
export MTK_PARTITION_TABLE_PLAIN_TEXT


PTGEN_FILE := device/mediatek/build/build/tools/ptgen/$(PLATFORM)/ptgen.pl

PTGEN_OUTPUT_FILE := device/mediatek/build/build/tools/ptgen/$(PLATFORM)/out/auto_check_out.txt
CHECK_OUT_FILE := $(PTGEN_OUTPUT_FILE)_new
all: $(PTGEN_FILE)
	perl $<
	cat $(PTGEN_OUTPUT_FILE) | sed -r 's/\/+/\//g' > $(CHECK_OUT_FILE) 

checkout : check_p4
	PTGEN_CHECKOUT=yes perl $(PTGEN_FILE)
	cat $(PTGEN_OUTPUT_FILE) | sed -r 's/\/+/\//g' > $(CHECK_OUT_FILE) 
	p4 edit `cat $(CHECK_OUT_FILE)` 2>/dev/null
	p4 add `cat $(CHECK_OUT_FILE)` 2>/dev/null	
	rm $(CHECK_OUT_FILE)


check_p4:
	@P4USER=`p4 set|grep P4USER`; \
	if [ "$$P4USER" == '' ]; then \
		echo "please set P4USER in you env, for example : export P4USER=abc.def"; \
		exit 1; \
	fi
	@P4CHARSET=`p4 set|grep P4CHARSET`; \
	if [ "$$P4CHARSET" == '' ]; then \
		echo "please set P4CHARSET in you env, for example : export P4CHARSET=utf8"; \
		exit 1; \
	fi
	@P4PORT=`p4 set|grep P4PORT`; \
	if [ "$$P4PORT" == '' ]; then \
		echo "please set P4PORT in you env, for example : export P4PORT=10.22.33.44:3010"; \
		exit 1; \
	fi
	@P4CLIENT=`p4 set|grep P4CLIENT`; \
	if [ "$$P4CLIENT" == '' ]; then \
		echo "please set P4CLIENT in you env, for example : export P4CLIENT=ws_abc.def_workspace"; \
		exit 1; \
	fi
