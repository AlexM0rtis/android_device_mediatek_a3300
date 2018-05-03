#!/usr/local/bin/perl -w
#
#****************************************************************************/
#* This script will generate partition layout files
#* Author: Liujiang Chen (MTK06418)
#*
#****************************************************************************/

#****************************************************************************
# Included Modules
#****************************************************************************
use File::Basename;
use File::Path qw(mkpath);
my $Version=3.7;
#my $ChangeHistory="3.1 AutoDetect eMMC Chip and Set MBR_Start_Address_KB\n";
#my $ChangeHistory = "3.2 Support OTP\n";
#my $ChangeHistory = "3.3 Support Shared SD Card\n";
#my $ChangeHistory = "3.4 CIP support\n";
#my $ChangeHistory = "3.5 Fix bug\n";
#my $ChangeHistory = "3.6 Support YAML format scatter file\n";
my $ChangeHistory = "3.7 change output file path\n";

# Partition_table.xls arrays and columns
my @PARTITION_FIELD ;
my @START_FIELD_Byte ;
my @START_ADDR_PHY_Byte_HEX;
my @START_FIELD_Byte_HEX;
my @SIZE_FIELD_KB ;
my @TYPE_FIELD;
my @DL_FIELD ;
my @PARTITION_IDX_FIELD ;
my @REGION_FIELD ;
my @RESERVED_FIELD;
my @BR_INDEX;
my @FB_ERASE_FIELD;
my @FB_DL_FIELD;

my $COLUMN_PARTITION                = 1 ;
my $COLUMN_TYPE                     = $COLUMN_PARTITION + 1 ;
my $COLUMN_SIZE                     = $COLUMN_TYPE + 1 ;
my $COLUMN_SIZEKB                   = $COLUMN_SIZE + 1 ;
my $COLUMN_SIZE2                    = $COLUMN_SIZEKB + 1 ;
my $COLUMN_SIZE3                    = $COLUMN_SIZE2 + 1 ;
my $COLUMN_DL                       = $COLUMN_SIZE3 + 1 ;
my $COLUMN_FB_ERASE                 = $COLUMN_DL + 1;  # fastboot support
my $COLUMN_FB_DL                    = $COLUMN_FB_ERASE + 1;  # fastboot support
# emmc support
my $COLUMN_REGION		    		= $COLUMN_FB_DL + 1;
my $COLUMN_RESERVED		    		= $COLUMN_REGION + 1;

my $PMT_END_NAME;  #PMT_END_NAME

my $total_rows = 0 ; #total_rows in partition_table
my $MBR_Start_Address_KB;	#KB
my $Page_Size	=2; # default NAND page_size of nand
my $DebugPrint    = 1; # 1 for debug; 0 for non-debug
my $LOCAL_PATH;
my $SCAT_NAME;
my $SHEET_NAME;
my $Min_user_region = 0;



BEGIN
{
  $LOCAL_PATH = dirname($0);
}
my $CD_ALPS;
$CD_ALPS="$LOCAL_PATH/../../../../../../.."; 
print "LOCAL_PATH: $LOCAL_PATH\n";
print "CD_ALPS: $CD_ALPS\n";

print "LOCAL_PATH: $LOCAL_PATH\n";
use lib "$LOCAL_PATH/../../Spreadsheet";
use lib "$LOCAL_PATH/../../";
require 'ParseExcel.pm';
use pack_dep_gen;

#parse argv from alps/mediatek/config/{project}/ProjectConfig.mk
$PLATFORM = $ENV{PLATFORM};
$platform = lc($PLATFORM);
$PROJECT = $ENV{PROJECT};
#overwrite project name
if(exists $ENV{MTK_TARGET_PROJECT})
{ 
	$PROJECT= $ENV{MTK_TARGET_PROJECT};
}
$BASEPROJECT = $ENV{BASEPROJECT};
$MTK_PROJECT_FOLDER = $ENV{MTK_PROJECT_FOLDER};
$MTK_TARGET_PROJECT_FOLDER = $ENV{MTK_TARGET_PROJECT_FOLDER};

###### $FULL_PROJECT = $ENV{FULL_PROJECT};
###### $PAGE_SIZE = $ENV{MTK_NAND_PAGE_SIZE};
$EMMC_SUPPORT= $ENV{MTK_EMMC_SUPPORT};
$LDVT_SUPPORT= $ENV{MTK_LDVT_SUPPORT};
###### $OPERATOR_SPEC = $ENV{OPTR_SPEC_SEG_DEF};
$MTK_EMMC_OTP_SUPPORT= $ENV{MTK_EMMC_SUPPORT_OTP};
$MTK_SHARED_SDCARD=$ENV{MTK_SHARED_SDCARD};
$TARGET_BUILD_VARIANT=$ENV{TARGET_BUILD_VARIANT};
$MTK_CUSTOM_PARTITION_SUPPORT = $ENV{MTK_CIP_SUPPORT};
$MTK_FACTORY_RESET_PROTECTION_SUPPORT = $ENV{MTK_FACTORY_RESET_PROTECTION_SUPPORT};
$MTK_FAT_ON_NAND=$ENV{MTK_FAT_ON_NAND};
$TRUSTONIC_TEE_SUPPORT = $ENV{TRUSTONIC_TEE_SUPPORT};
$MTK_DRM_KEY_MNG_SUPPORT = $ENV{MTK_DRM_KEY_MNG_SUPPORT};
$MTK_PERSIST_PARTITION_SUPPORT=$ENV{MTK_PERSIST_PARTITION_SUPPORT};
$MTK_NAND_UBIFS_SUPPORT=$ENV{MTK_NAND_UBIFS_SUPPORT};
$YAML_SUPPORT=$ENV{MTK_YAML_SCATTER_FILE_SUPPORT};
$SPI_NAND_SUPPORT=$ENV{MTK_SPI_NAND_SUPPORT};
my $COMBO_NAND_SUPPORT = $ENV{MTK_COMBO_NAND_SUPPORT};

my $CUSTOM_BASEPROJECT;
my $PTGEN_XLS=$ENV{PTGEN_XLS};

if (exists $ENV{BASEPROJECT})
{	
	$CUSTOM_BASEPROJECT = $ENV{BASEPROJECT};
}
elsif (exists $ENV{MTK_BASE_PROJECT}) 
{
	$CUSTOM_BASEPROJECT = $ENV{MTK_BASE_PROJECT};
}
else
{
	$CUSTOM_BASEPROJECT = $PROJECT;
}


my $PROJECT_PART_TABLE_FILENAME;


##############  input  #############

my $PART_TABLE_FILENAME			= "$CD_ALPS/device/mediatek/build/build/tools/ptgen/$PLATFORM/partition_table_${PLATFORM}.xls"; # excel file name
my $CUSTOM_MEMORYDEVICE_H_NAME  = "$CD_ALPS/bootable/bootloader/preloader/custom/$CUSTOM_BASEPROJECT/inc/custom_MemoryDevice.h";
my $REGION_TABLE_FILENAME 		= "$CD_ALPS/device/mediatek/build/build/tools/emigen/$PLATFORM/MemoryDeviceList_${PLATFORM}.xls";  #eMMC region information
my $EMMC_COMPO					= "$CD_ALPS/device/mediatek/build/build/tools/ptgen/MT6582/mbr_addr.pl" ;
my $CUSTOM_EMMC_COMPO			= "$CD_ALPS/$MTK_PROJECT_FOLDER/mbr_addr.pl" ;


##############  output #############
# temp output path
if(exists $ENV{TMP_OUT_PATH})
{
	$OUT_PATH = $ENV{TMP_OUT_PATH};
} 
else
{  
	$OUT_PATH="$CD_ALPS/device/mediatek/build/build/tools/ptgen/$PLATFORM/out";
}

my $PART_SIZE_LOCATION			= "$OUT_PATH/partition_size.mk" ; # store the partition size for ext4 buil
my $SCAT_NAME_DIR   			= "$OUT_PATH"; # 
my $AUTO_CHECK_OUT_FILES		= "$OUT_PATH/auto_check_out.txt";


#####   final output path   #####
if(exists $ENV{PTGEN_PROJECT_OUT})  
{
	$COPY_PATH_PART_SIZE_LOCATION=$ENV{PTGEN_PROJECT_OUT};   
}
else
{
	$COPY_PATH_PART_SIZE_LOCATION="$ENV{OUT_DIR}/target/product/$PROJECT/obj/PTGEN";
}

if(exists $ENV{PRODUCT_OUT})  
{
	$COPY_SCATTER_BR_FILES_PATH=$ENV{PRODUCT_OUT};
}
else
{
	$COPY_SCATTER_BR_FILES_PATH= "$ENV{OUT_DIR}/target/product/$PROJECT";
}

#####   clean the output path   #####
if (-e $OUT_PATH) {
	`rm -fr $OUT_PATH`;
}

#Set SCAT_NAME
mkdir($SCAT_NAME_DIR) if (!-d $SCAT_NAME_DIR);
if($YAML_SUPPORT eq "yes"){
	$SCAT_NAME = "${SCAT_NAME_DIR}/${PLATFORM}_Android_scatter.txt";
}else{
	if ($EMMC_SUPPORT eq "yes") 
	{
	     $SCAT_NAME = $SCAT_NAME_DIR."/" . $PLATFORM ."_Android_scatter_emmc.txt" ;
	}else{
	     $SCAT_NAME = $SCAT_NAME_DIR."/" . $PLATFORM ."_Android_scatter.txt" ;
	}
}

#Set SHEET_NAME
if($EMMC_SUPPORT eq "yes"){
	$SHEET_NAME = "emmc";
	if($MTK_EMMC_OTP_SUPPORT eq "yes"){
		$SHEET_NAME = $SHEET_NAME ." otp" ;
    if(!defined $TARGET_BUILD_VARIANT || $TARGET_BUILD_VARIANT eq ""){
      $SHEET_NAME = $SHEET_NAME . " eng";
    }else{
      if($TARGET_BUILD_VARIANT eq "eng"){
        $SHEET_NAME = $SHEET_NAME . " eng";
      }else{
        $SHEET_NAME = $SHEET_NAME . " user"; 
      }
    }		
	}
	else
	{
    if(!defined $TARGET_BUILD_VARIANT || $TARGET_BUILD_VARIANT eq ""){
      $SHEET_NAME = $SHEET_NAME . " eng";
    }else{
      if($TARGET_BUILD_VARIANT eq "eng"){
        $SHEET_NAME = $SHEET_NAME . " eng";
      }else{
        $SHEET_NAME = $SHEET_NAME . " user"; 
      }
    }
	}
}
if($LDVT_SUPPORT eq "yes"){
	$SHEET_NAME = "ldvt";
}


#****************************************************************************
# main thread
#****************************************************************************
# get already active Excel application or open new
PrintDependModule($0);
print "*******************Arguments*********************\n" ;
print "Version=$Version ChangeHistory:$ChangeHistory\n";
print "PLATFORM = $ENV{PLATFORM};
PROJECT = $ENV{PROJECT};
PAGE_SIZE = $ENV{MTK_NAND_PAGE_SIZE};
EMMC_SUPPORT= $ENV{MTK_EMMC_SUPPORT};
LDVT_SUPPORT= $ENV{MTK_LDVT_SUPPORT};
TARGET_BUILD_VARIANT= $ENV{TARGET_BUILD_VARIANT};
MTK_EMMC_OTP_SUPPORT= $ENV{MTK_EMMC_OTP_SUPPORT};
OPERATOR_SPEC = $ENV{OPTR_SPEC_SEG_DEF};
MTK_SHARED_SDCARD=$ENV{MTK_SHARED_SDCARD};
MTK_CUSTOM_PARTITION_SUPPORT=$ENV{MTK_CUSTOM_PARTITION_SUPPORT};
TRUSTONIC_TEE_SUPPORT=$ENV{TRUSTONIC_TEE_SUPPORT};
MTK_PERSIST_PARTITION_SUPPORT=$ENV{MTK_PERSIST_PARTITION_SUPPORT};
MTK_DRM_KEY_MNG_SUPPORT=$ENV{MTK_DRM_KEY_MNG_SUPPORT};
MTK_NAND_UBIFS_SUPPORT=$ENV{MTK_NAND_UBIFS_SUPPORT};
MTK_YAML_SCATTER_FILE_SUPPORT=$ENV{MTK_YAML_SCATTER_FILE_SUPPORT};
BASEPROJECT = $CUSTOM_BASEPROJECT;
PTGEN_XLS=$PTGEN_XLS;
\n";
print "SHEET_NAME=$SHEET_NAME\n";
print "SCAT_NAME=$SCAT_NAME\n" ;

print "*******************Arguments*********************\n\n\n\n" ;

if ($EMMC_SUPPORT eq "yes"){
	&GetMBRStartAddress();
}

#$PartitonBook = Spreadsheet::ParseExcel->new()->Parse($PART_TABLE_FILENAME);

&InitAlians();

&ReadExcelFile () ;

if($YAML_SUPPORT eq "yes"){
	&GenYAMLScatFile();
}else{
	&GenScatFile () ;
}

if ($EMMC_SUPPORT eq "yes"){
	&GenMBRFile ();
}
if ($EMMC_SUPPORT eq "yes" || $MTK_NAND_UBIFS_SUPPORT eq "yes"){
	&GenPartSizeFile ();
}
&do_copy_files();
print "**********Ptgen Done********** ^_^\n" ;

print "\n\nPtgen modified or Generated files list:\n$SCAT_NAME\n$PART_SIZE_LOCATION\n/out/MBR EBR1 EBR2 \n\n\n\n\n";

exit ;

sub GetMBRStartAddress()
{
	my %REGION_TABLE;
	my $BOOT1;
	my $BOOT2;
	my $RPMB;
	my $USER;

	my $EMMC_REGION_SHEET_NAME = "emmc_region";
	my $emmc_sheet;
	my $region_name;
	my $region = 0;
	my $boot1 = 2;
	my $boot2 = 3;
	my $rpmb = 4;
	my $user = 9;
	my $EMMC_RegionBook = Spreadsheet::ParseExcel->new()->Parse($REGION_TABLE_FILENAME);
	print "GetMBRStartAddress==>REGION_TABLE_FILENAME : $REGION_TABLE_FILENAME\n";	
	#print "GetMBRStartAddress==>EMMC_RegionBook : $EMMC_RegionBook\n";	
	PrintDependency($REGION_TABLE_FILENAME);

	$emmc_sheet = get_sheet($EMMC_REGION_SHEET_NAME,$EMMC_RegionBook) ;
	unless ($emmc_sheet)
	{
		my $error_msg="Ptgen CAN NOT find sheet=$EMMC_REGION_SHEET_NAME in $REGION_TABLE_FILENAME\n";
		print $error_msg;
		die $error_msg;
	}

	my $row = 1;
    $region_name = &xls_cell_value($emmc_sheet, $row, $region,$EMMC_REGION_SHEET_NAME);
	while($region_name ne "END"){
		$region_name	=~ s/\s+//g;
		$BOOT1     	= &xls_cell_value($emmc_sheet, $row, $boot1,$EMMC_REGION_SHEET_NAME);
		$BOOT2     	= &xls_cell_value($emmc_sheet, $row, $boot2,$EMMC_REGION_SHEET_NAME);
		$RPMB   	= &xls_cell_value($emmc_sheet, $row, $rpmb,$EMMC_REGION_SHEET_NAME);
		$USER		= &xls_cell_value($emmc_sheet, $row, $user,$EMMC_REGION_SHEET_NAME);
		$REGION_TABLE{$region_name}	= {BOOT1=>$BOOT1,BOOT2=>$BOOT2,RPMB=>$RPMB,USER=>$USER};
		print "In $region_name,$BOOT1,$BOOT2,$RPMB,$USER\n";
		$row++;
		$region_name = &xls_cell_value($emmc_sheet, $row, $region,$EMMC_REGION_SHEET_NAME);
	}

	#if (-e $CUSTOM_MEMORYDEVICE_H_NAME) {
	#	`chmod 777 $CUSTOM_MEMORYDEVICE_H_NAME`;
	#} 
	my $CUSTOM_MEMORYDEVICE_H_NAME_fh = &open_for_read($CUSTOM_MEMORYDEVICE_H_NAME);
    PrintDependency($CUSTOM_MEMORYDEVICE_H_NAME);

	my @lines;
	my $iter = 0;
	my $part_num;
	my $MAX_address = 0;
	my $combo_start_address = 0;
	my $cur=0;
	my $cur_user=0;
	while (<$CUSTOM_MEMORYDEVICE_H_NAME_fh>) {
		my($line) = $_;
  		chomp($line);
		if ($line =~ /^#define\sCS_PART_NUMBER\[[0-9]\]/) {
#			print "$'\n";
			$lines[$iter] = $';
			$lines[$iter] =~ s/\s+//g;
			if ($lines[$iter] =~ /(.*)\/\/(.*)/) {
				$lines[$iter] =$1;
			}
			#print "$lines[$iter] \n";
			$iter ++;
		}

	}
	foreach $part_num (@lines) {
		if(exists $REGION_TABLE{$part_num}){
			$cur = $REGION_TABLE{$part_num}{BOOT1} + $REGION_TABLE{$part_num}{BOOT2} + $REGION_TABLE{$part_num}{RPMB};
			$cur_user = $REGION_TABLE{$part_num}{USER};
			print "Chose region layout: $part_num, $REGION_TABLE{$part_num}{BOOT1} + $REGION_TABLE{$part_num}{BOOT2} + $REGION_TABLE{$part_num}{RPMB}=$cur \$REGION_TABLE{\$part_num}{USER}=$cur_user\n";
			if ($cur > $MAX_address) {
				$MAX_address = $cur;
			}
			if($cur_user < $Min_user_region || $Min_user_region == 0){
				$Min_user_region = 	$cur_user;
			}
			#print "\$Min_user_region=$Min_user_region\n";
		}else{
			$MAX_address = $MAX_address>6*1024 ? $MAX_address : 6*1024;
			my $error_msg="WARNING:Ptgen CAN NOT find $part_num in $REGION_TABLE_FILENAME\n";
			print $error_msg;
#			die $error_msg;
		}
	}
	print "The MAX BOOT1+BOOT2+RPMB=$MAX_address  \$Min_user_region=$Min_user_region in $CUSTOM_MEMORYDEVICE_H_NAME\n";

	if (-e $EMMC_COMPO)
	{
		`chmod 777 $EMMC_COMPO`;
		$combo_start_address = do "$EMMC_COMPO";
		PrintDependency($EMMC_COMPO);
	}else{
		print "No $EMMC_COMPO\n";
	}
	if (-e $CUSTOM_EMMC_COMPO)
	{
		`chmod 777 $CUSTOM_EMMC_COMPO`;
		$combo_start_address = do "$CUSTOM_EMMC_COMPO";
		print "CUSTOM EMMC_COMPO \n";
		PrintDependency($CUSTOM_EMMC_COMPO);
	}

	if ($MAX_address < $combo_start_address) {
		$MBR_Start_Address_KB = $combo_start_address;
		print "Get MBR_Start_Address_KB from EMMC_COMPO = $combo_start_address\n";
	}else{
		$MBR_Start_Address_KB = $MAX_address;
		print "Get MBR_Start_Address_KB from $CUSTOM_MEMORYDEVICE_H_NAME = $MAX_address\n";
	}
}

#****************************************************************************
# subroutine:  InitAlians
# return:
#****************************************************************************
sub InitAlians()
{

}

#****************************************************************************
# subroutine:  ReadExcelFile
# return:
#****************************************************************************

sub ReadExcelFile()
{
    my $sheet = load_partition_info($SHEET_NAME);
    my $row_t = 1;
	my $row = 1 ;
    my $pt_name = &xls_cell_value($sheet, $row, $COLUMN_PARTITION,$SHEET_NAME);
	my $px_index = 1;
	my $px_index_t = 1;
	my $br_index = 0;
	my $p_count = 0;
	my $br_count =0;
	while($pt_name ne "END"){
		$type		 = &xls_cell_value($sheet, $row, $COLUMN_TYPE,$SHEET_NAME) ;
		if($type eq "EXT4" || $type eq "FAT" ){
			if($pt_name eq "FAT" && $MTK_SHARED_SDCARD eq "yes"){
				print "Skip FAT because of MTK_SHARED_SDCARD On\n";
  			}elsif($pt_name eq "CUSTOM" && $MTK_CUSTOM_PARTITION_SUPPORT ne "yes"){
	  			print "Skip CUSTOM because of MTK_CUSTOM_PARTITION_SUPPORT off\n";
            }elsif($pt_name eq "TEE1" && $TRUSTONIC_TEE_SUPPORT ne "yes"){
	  			print "Skip TEE1 because of TRUSTONIC_TEE_SUPPORT off\n";
	  	    }elsif($pt_name eq "TEE2" && $TRUSTONIC_TEE_SUPPORT ne "yes"){
	  			print "Skip TEE2 because of TRUSTONIC_TEE_SUPPORT off\n";
			}elsif($pt_name eq "PERSIST" && $MTK_PERSIST_PARTITION_SUPPORT ne "yes"){
	  			print "Skip persist because of MTK_PERSIST_PARTITION_SUPPORT off\n";
      		}elsif($pt_name eq "KB" && $MTK_DRM_KEY_MNG_SUPPORT ne "yes"){
	  			print "Skip KB because of MTK_DRM_KEY_MNG_SUPPORT off\n";
      		}elsif($pt_name eq "DKB" && $MTK_DRM_KEY_MNG_SUPPORT ne "yes"){
	  			print "Skip DKB because of MTK_DRM_KEY_MNG_SUPPORT off\n";
			}else{
						$p_count++;
			}
		}
		$row++;
		$pt_name = &xls_cell_value($sheet, $row, $COLUMN_PARTITION,$SHEET_NAME);
	}
	$br_count = int(($p_count+2)/3)-1;

	$row =1;
	$pt_name = &xls_cell_value($sheet, $row, $COLUMN_PARTITION,$SHEET_NAME);
	my $tmp_index=1;
	my $skip_fat=0;

	if($EMMC_SUPPORT eq "yes"){
		$skip_fat=0;
		if($MTK_SHARED_SDCARD eq "yes"){
			$skip_fat=1;
		}
	}else{
		$skip_fat=1;
		if($MTK_FAT_ON_NAND eq "yes"){
			$skip_fat=0;
		}
	}
	while($pt_name ne "END"){
		if($pt_name eq "FAT" && $skip_fat==1 ){
			print "Skip FAT because of MTK_SHARED_SDCARD or MTK_FAT_ON_NAND\n";
		}elsif($pt_name eq "CUSTOM" && $MTK_CUSTOM_PARTITION_SUPPORT ne "yes"){
			print "Skip CUSTOM because of MTK_CUSTOM_PARTITION_SUPPORT off\n";
        }elsif($pt_name eq "TEE1" && $TRUSTONIC_TEE_SUPPORT ne "yes"){
			print "Skip TEE1 because of TRUSTONIC_TEE_SUPPORT off\n";
		}elsif($pt_name eq "TEE2" && $TRUSTONIC_TEE_SUPPORT ne "yes"){
			print "Skip TEE2 because of TRUSTONIC_TEE_SUPPORT off\n";
		}elsif($pt_name eq "PERSIST" && $MTK_PERSIST_PARTITION_SUPPORT ne "yes"){
			print "Skip persist because of MTK_PERSIST_PARTITION_SUPPORT off\n";
		}elsif($pt_name eq "KB" && $MTK_DRM_KEY_MNG_SUPPORT ne "yes"){
			print "Skip KB because of MTK_DRM_KEY_MNG_SUPPORT off\n";
		}elsif($pt_name eq "DKB" && $MTK_DRM_KEY_MNG_SUPPORT ne "yes"){
			print "Skip DKB because of MTK_DRM_KEY_MNG_SUPPORT off\n";
		}elsif($pt_name eq "FRP" && $MTK_FACTORY_RESET_PROTECTION_SUPPORT ne "yes"){
			print "Skip FRP because of MTK_FACTORY_RESET_PROTECTION_SUPPORT off\n";
		}else{
			$PARTITION_FIELD[$row_t -1] 	= $pt_name;
			$SIZE_FIELD_KB[$row_t -1]    	= &xls_cell_value($sheet, $row, $COLUMN_SIZEKB,$SHEET_NAME) ;
			$DL_FIELD[$row_t-1]        		= &xls_cell_value($sheet, $row, $COLUMN_DL,$SHEET_NAME) ;
			$TYPE_FIELD[$row_t -1]		 	= &xls_cell_value($sheet, $row, $COLUMN_TYPE,$SHEET_NAME) ;
			$FB_DL_FIELD[$row_t-1]    		= &xls_cell_value($sheet, $row, $COLUMN_FB_DL,$SHEET_NAME) ;
 			$FB_ERASE_FIELD[$row_t-1]    	= &xls_cell_value($sheet, $row, $COLUMN_FB_ERASE,$SHEET_NAME) ;
        	$REGION_FIELD[$row_t-1]   	    = &xls_cell_value($sheet, $row, $COLUMN_REGION,$SHEET_NAME) ;
        	$RESERVED_FIELD[$row_t-1]		= &xls_cell_value($sheet, $row, $COLUMN_RESERVED,$SHEET_NAME) ;
			if($TYPE_FIELD[$row_t -1] eq "EXT4" || $TYPE_FIELD[$row_t -1] eq "FAT"){
				$PARTITION_IDX_FIELD[$row_t-1] = $px_index;
				$BR_INDEX[$px_index] = int(($px_index_t+2)/3)-1;
				$px_index++;
				$px_index_t++;
			}else{
				$PARTITION_IDX_FIELD[$row_t-1] = 0;
			}
			##add EBR1 after MBR
			if($pt_name =~ /MBR/ && ($br_count >= 1)){
				$row_t++;
				$PARTITION_FIELD[$row_t-1] 		= "EBR1";
				$SIZE_FIELD_KB[$row_t -1] 		= 512;
				$DL_FIELD[$row_t-1] 			= 1;
				if($TARGET_BUILD_VARIANT eq "user"){
					$FB_DL_FIELD[$row_t-1] 		= 0;
					$FB_ERASE_FIELD[$row_t-1] 	= 0;
				}else{
					$FB_DL_FIELD[$row_t-1] 		= 1;
					$FB_ERASE_FIELD[$row_t-1] 	= 1;
				}

				$REGION_FIELD[$row_t-1] 		= "USER";
				$TYPE_FIELD[$row_t -1] 			= "Raw data";
				$RESERVED_FIELD[$row_t-1]		= 0 ;

				print "ebr $px_index $br_count\n";
				$PARTITION_IDX_FIELD[$row_t-1]	= $px_index;
				$BR_INDEX[$px_index] 			= 0;
				$px_index++;
			}
          	##add EBR2~ after LOGO
			if(($br_count >= 2) && $pt_name eq "LOGO"){
				for($tmp_index=2;$tmp_index<=$br_count;$tmp_index++){
					$row_t++;
					$PARTITION_FIELD[$row_t-1] 		= sprintf("EBR%d",$tmp_index);
					$SIZE_FIELD_KB[$row_t -1] 		= 512;
					$DL_FIELD[$row_t-1] 			= 1;
					if($TARGET_BUILD_VARIANT eq "user"){
						$FB_DL_FIELD[$row_t-1] 		= 0;
						$FB_ERASE_FIELD[$row_t-1] 	= 0;
					}else{
						$FB_DL_FIELD[$row_t-1] 		= 1;
						$FB_ERASE_FIELD[$row_t-1] 	= 1;
					}

					$REGION_FIELD[$row_t-1] 		= "USER";
					$TYPE_FIELD[$row_t -1] 			= "Raw data";
					$RESERVED_FIELD[$row_t-1] 		= 0 ;
					$PARTITION_IDX_FIELD[$row_t-1]	= 0;
				}
			}
		
			$row_t++;
		}

		$row++;
		$pt_name = &xls_cell_value($sheet, $row, $COLUMN_PARTITION,$SHEET_NAME);
	}

	#modify size for some part in base project
    my $board_config = &open_for_read("$MTK_PROJECT_FOLDER/BoardConfig.mk");
    my $iter;
    if ($board_config)
    {
        my $line;
        while (defined($line = <$board_config>))
        {
            for($iter=0;$iter< @PARTITION_FIELD;$iter++)
            {
                my $part_name = $PARTITION_FIELD[$iter];
                if ($line =~ /\A\s*BOARD_MTK_${part_name}_SIZE_KB\s*:=\s*(\d+)/)
                {
                    $SIZE_FIELD_KB[$iter] = $1;
                    print "by project size $part_name = $1 KB\n";
                }
            }
        }
        close $board_config;
    }

	#modify size for some part in flavor project
	if ($CUSTOM_BASEPROJECT ne $PROJECT )
	{
		my $flavor_board_config = &open_for_read("$MTK_TARGET_PROJECT_FOLDER/BoardConfig.mk");
		my $iter;
		if ($flavor_board_config)
		{
			my $line;
			while (defined($line = <$flavor_board_config>))
			{
				for($iter=0;$iter< @PARTITION_FIELD;$iter++)
				{
					my $part_name = $PARTITION_FIELD[$iter];
					if ($line =~ /\A\s*BOARD_MTK_${part_name}_SIZE_KB\s*:=\s*(\d+)/)
					{
						$SIZE_FIELD_KB[$iter] = $1;
						print "by project size $part_name = $1 KB\n";
					}
				}
			}	
			close $flavor_board_config;
		}
	}
	#init start_address of partition
	$START_FIELD_Byte[0] 	= 0;
	$PARTITION_IDX_FIELD[0] = 0;
	my $otp_row;
	my $reserve_size;
	for($row=1;$row < @PARTITION_FIELD;$row++){
		if($PARTITION_FIELD[$row] eq "MBR"){
			$START_FIELD_Byte[$row] = $MBR_Start_Address_KB*1024;
			$SIZE_FIELD_KB[$row-1] 	= ($START_FIELD_Byte[$row] - $START_FIELD_Byte[$row-1])/1024;
			next;
		}
		if($PARTITION_FIELD[$row] eq "BMTPOOL" || $PARTITION_FIELD[$row] eq "OTP"){
		#	$START_FIELD_Byte[$row] = &xls_cell_value($sheet, $row+1, $COLUMN_START,$SHEET_NAME);
			$START_FIELD_Byte[$row] = $SIZE_FIELD_KB[$row]*1024;
			if($PARTITION_FIELD[$row] eq "OTP"){
					$otp_row = $row;
				}
			next;
		}

		$START_FIELD_Byte[$row] = $START_FIELD_Byte[$row-1]+$SIZE_FIELD_KB[$row-1]*1024;
	}

	if($MTK_EMMC_OTP_SUPPORT eq "yes"){
		for($row=$otp_row+1;$row < @PARTITION_FIELD;$row++){
		 	if($RESERVED_FIELD[$row] == 1){
				$reserve_size += $START_FIELD_Byte[$row];
		 	}
		}
		$START_FIELD_Byte[$otp_row] += $reserve_size;
	}

	#convert dec start_address to hex start_address
	$START_FIELD_Byte_HEX[0]=0;
	for($row=1;$row < @PARTITION_FIELD;$row++){
		if($PARTITION_FIELD[$row] eq "BMTPOOL" || $PARTITION_FIELD[$row] eq "OTP"){
		 # this field is only used for eMMC, COMBO_NAND didn't need to change. 		 
			$START_FIELD_Byte_HEX[$row] = sprintf("FFFF%04x",$START_FIELD_Byte[$row]/(64*$Page_Size*1024));#$START_FIELD_Byte[$row];
		}else{
			$START_FIELD_Byte_HEX[$row] = sprintf("%x",$START_FIELD_Byte[$row]);
		}
	}

	if($DebugPrint eq 1){
		for($row=0;$row < @PARTITION_FIELD;$row++){
			print "START=0x$START_FIELD_Byte_HEX[$row],		Partition=$PARTITION_FIELD[$row],		SIZE=$SIZE_FIELD_KB[$row],	DL_=$DL_FIELD[$row]" ;
			if ($EMMC_SUPPORT eq "yes"){
            	print ", 	Partition_Index=$PARTITION_IDX_FIELD[$row],	REGION =$REGION_FIELD[$row],RESERVE = $RESERVED_FIELD[$row]";
        	}
			print "\n";
		}

	}

    $total_rows = @PARTITION_FIELD ;

	if ($total_rows == 0)
    {
        die "error in excel file no data!\n" ;
    }
    print "There are $total_rows Partition totally!.\n" ;
}

#****************************************************************************
# subroutine:  GenScatFile
# return:
#****************************************************************************
sub GenScatFile ()
{
    my $iter = 0 ;
	`chmod 777 $SCAT_NAME_DIR` if (-e $SCAT_NAME_DIR);
    open (SCAT_NAME, ">$SCAT_NAME") or &error_handler("Ptgen open $SCAT_NAME Fail!", __FILE__, __LINE__) ;

    for ($iter=0; $iter<$total_rows; $iter++)
    {
		my $temp;
        if ($DL_FIELD[$iter] == 0)
        {
            $temp .= "__NODL_" ;
        }
	if($EMMC_SUPPORT eq "yes" && $RESERVED_FIELD[$iter] == 1 && $PLATFORM eq "MT6589"){
			$temp .= "RSV_";
	}
	$temp .= "$PARTITION_FIELD[$iter]" ;

	if($MTK_SHARED_SDCARD eq "yes" && $PARTITION_FIELD[$iter] =~ /USRDATA/){
		$PMT_END_NAME = "$temp";
	}elsif($PARTITION_FIELD[$iter] =~ /FAT/){
		$PMT_END_NAME = "$temp";
	}

	$temp .= " 0x$START_FIELD_Byte_HEX[$iter]\n{\n}\n";


        print SCAT_NAME $temp ;
    }

    print SCAT_NAME "\n\n" ;
    close SCAT_NAME ;
}

sub GenYAMLScatFile()
{
	my $iter = 0 ;
	if(!-e $SCAT_NAME_DIR)
	{
		`mkdir -p $SCAT_NAME_DIR `;
	}
	if(-e $SCAT_NAME)
	{
		`chmod 777 $SCAT_NAME`;
	}
    open (SCAT_NAME, ">$SCAT_NAME") or &error_handler("Ptgen open $SCAT_NAME Fail!", __FILE__, __LINE__) ;
	my %fileHash=(
		PRELOADER=>"preloader_$CUSTOM_BASEPROJECT.bin",
		DSP_BL=>"DSP_BL",
		SRAM_PRELD=>"sram_preloader_$CUSTOM_BASEPROJECT.bin",
		MEM_PRELD=>"mem_preloader_$CUSTOM_BASEPROJECT.bin",
		UBOOT=>"lk.bin",
		SBOOT=>"sboot.bin",
		TEE1=>"trustzone.bin",
		TEE2=>"trustzone.bin",
		BOOTIMG=>"boot.img",
		RECOVERY=>"recovery.img",
		SEC_RO=>"secro.img",
		LOGO=>"logo.bin",
		CUSTOM=>"custom.img",
		ANDROID=>"system.img",
		CACHE=>"cache.img",
		USRDATA=>"userdata.img"
	);
	my %sepcial_operation_type=(
		PRELOADER=>"BOOTLOADERS",
		DSP_BL=>"BOOTLOADERS",
		NVRAM=>"BINREGION",
		PRO_INFO=>"PROTECTED",
		PROTECT_F=>"PROTECTED",
		PROTECT_S=>"PROTECTED",
		PERSIST=>"PROTECTED",
		OTP=>"RESERVED",
		PMT=>"RESERVED",
		BMTPOOL=>"RESERVED",
	);
	my %protect=(PRO_INFO=>"TRUE",NVRAM=>"TRUE",PROTECT_F=>"TRUE",PROTECT_S=>"TRUE",FAT=>"KEEPVISIBLE",FAT=>"INVISIBLE",BMTPOOL=>"INVISIBLE");
	my %Scatter_Info={};
	for ($iter=0; $iter<$total_rows; $iter++){
		$Scatter_Info{$PARTITION_FIELD[$iter]}={partition_index=>$iter,physical_start_addr=>sprintf("0x%x",$START_ADDR_PHY_Byte_DEC[$iter]),linear_start_addr=>"0x$START_FIELD_Byte_HEX[$iter]",partition_size=>sprintf("0x%x",${SIZE_FIELD_KB[$iter]}*1024)};
	
		if(exists $fileHash{$PARTITION_FIELD[$iter]}){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{file_name}=$fileHash{$PARTITION_FIELD[$iter]};
		}else{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{file_name}="NONE";
		}

		if($PARTITION_FIELD[$iter]=~/MBR/ || $PARTITION_FIELD[$iter]=~/EBR/){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{file_name}=$PARTITION_FIELD[$iter];
		}

		if($DL_FIELD[$iter] == 0){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{type}="NONE";
		}else{
			if($EMMC_SUPPORT eq "yes"){
			  if($TYPE_FIELD[$iter] eq "Raw data"){
			    $Scatter_Info{$PARTITION_FIELD[$iter]}{type}="NORMAL_ROM";
			  }else{
			    $Scatter_Info{$PARTITION_FIELD[$iter]}{type}="YAFFS_IMG";
			  }
			}else{
			  if($TYPE_FIELD[$iter] eq "Raw data"){
  				$Scatter_Info{$PARTITION_FIELD[$iter]}{type}="NORMAL_ROM";
	  			}else{
					if($MTK_NAND_UBIFS_SUPPORT eq "yes"){
			  			$Scatter_Info{$PARTITION_FIELD[$iter]}{type}="UBI_IMG";
  					}else{
				 	  $Scatter_Info{$PARTITION_FIELD[$iter]}{type}="YAFFS_IMG";
				  }
			  }
			}
		}
		if($PARTITION_FIELD[$iter]=~/MBR/ || $PARTITION_FIELD[$iter]=~/EBR/){
			#$Scatter_Info{$PARTITION_FIELD[$iter]}{type}="MBR_BIN";
		}
		if($PARTITION_FIELD[$iter]=~/PRELOADER/ || $PARTITION_FIELD[$iter]=~/DSP_BL/)
		{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{type}="SV5_BL_BIN";
		}
		if(exists $sepcial_operation_type{$PARTITION_FIELD[$iter]}){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{operation_type}=$sepcial_operation_type{$PARTITION_FIELD[$iter]};
		}else{
			if($DL_FIELD[$iter] == 0){
				$Scatter_Info{$PARTITION_FIELD[$iter]}{operation_type}="INVISIBLE";
			}else{
				$Scatter_Info{$PARTITION_FIELD[$iter]}{operation_type}="UPDATE";
			}
		}
		if($EMMC_SUPPORT eq "yes"){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{region}="EMMC_$REGION_FIELD[$iter]";
		}else{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{region}="NONE";
		}

		if($EMMC_SUPPORT eq "yes"){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{storage}="HW_STORAGE_EMMC";
		}else{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{storage}="HW_STORAGE_NAND";
		}

		if($PARTITION_FIELD[$iter]=~/BMTPOOL/ || $PARTITION_FIELD[$iter]=~/OTP/){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{boundary_check}="false";
		}else{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{boundary_check}="true";
		}

		if ($DL_FIELD[$iter] == 0){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{is_download}="false";
		}else{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{is_download}="true";
		}

		if($PARTITION_FIELD[$iter]=~/BMTPOOL/ || $PARTITION_FIELD[$iter]=~/OTP/){
			$Scatter_Info{$PARTITION_FIELD[$iter]}{is_reserved}="true";
		}else{
			$Scatter_Info{$PARTITION_FIELD[$iter]}{is_reserved}="false";
		}

		if($MTK_SHARED_SDCARD eq "yes" && $PARTITION_FIELD[$iter] =~ /USRDATA/){
			$PMT_END_NAME = $PARTITION_FIELD[$iter];
		}elsif($PARTITION_FIELD[$iter] =~ /FAT/){
			$PMT_END_NAME = $PARTITION_FIELD[$iter];
		}
	}
my $Head1 = <<"__TEMPLATE";
############################################################################################################
#
#  General Setting
#
############################################################################################################
__TEMPLATE

my $Head2=<<"__TEMPLATE";
############################################################################################################
#
#  Layout Setting
#
############################################################################################################
__TEMPLATE

	my ${FirstDashes}="- ";
	my ${FirstSpaceSymbol}="  ";
	my ${SecondSpaceSymbol}="      ";
	my ${SecondDashes}="    - ";
	my ${colon}=": ";
	print SCAT_NAME $Head1;
	print SCAT_NAME "${FirstDashes}general${colon}MTK_PLATFORM_CFG\n";
	print SCAT_NAME "${FirstSpaceSymbol}info${colon}\n";
	print SCAT_NAME "${SecondDashes}config_version${colon}V1.1.1\n";
	print SCAT_NAME "${SecondSpaceSymbol}platform${colon}${PLATFORM}\n";
	print SCAT_NAME "${SecondSpaceSymbol}project${colon}${PROJECT}\n";
	if($EMMC_SUPPORT eq "yes"){
		print SCAT_NAME "${SecondSpaceSymbol}storage${colon}EMMC\n";
		print SCAT_NAME "${SecondSpaceSymbol}boot_channel${colon}MSDC_0\n";
		printf SCAT_NAME ("${SecondSpaceSymbol}block_size${colon}0x%x\n",2*64*1024);
	}else{
		print SCAT_NAME "${SecondSpaceSymbol}storage${colon}NAND\n";
		print SCAT_NAME "${SecondSpaceSymbol}boot_channel${colon}NONE\n";
		printf SCAT_NAME ("${SecondSpaceSymbol}block_size${colon}0x%x\n",${Page_Size}*64*1024);
	}
	print SCAT_NAME $Head2;
	for ($iter=0; $iter<$total_rows; $iter++){
		print SCAT_NAME "${FirstDashes}partition_index${colon}SYS$Scatter_Info{$PARTITION_FIELD[$iter]}{partition_index}\n";
		print SCAT_NAME "${FirstSpaceSymbol}partition_name${colon}${PARTITION_FIELD[$iter]}\n";
		print SCAT_NAME "${FirstSpaceSymbol}file_name${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{file_name}\n";
		print SCAT_NAME "${FirstSpaceSymbol}is_download${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{is_download}\n";
		print SCAT_NAME "${FirstSpaceSymbol}type${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{type}\n";
		print SCAT_NAME "${FirstSpaceSymbol}linear_start_addr${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{linear_start_addr}\n";
		print SCAT_NAME "${FirstSpaceSymbol}physical_start_addr${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{physical_start_addr}\n";
		print SCAT_NAME "${FirstSpaceSymbol}partition_size${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{partition_size}\n";
		print SCAT_NAME "${FirstSpaceSymbol}region${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{region}\n";
		print SCAT_NAME "${FirstSpaceSymbol}storage${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{storage}\n";
		print SCAT_NAME "${FirstSpaceSymbol}boundary_check${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{boundary_check}\n";
		print SCAT_NAME "${FirstSpaceSymbol}is_reserved${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{is_reserved}\n";
		print SCAT_NAME "${FirstSpaceSymbol}operation_type${colon}$Scatter_Info{$PARTITION_FIELD[$iter]}{operation_type}\n";
		print SCAT_NAME "${FirstSpaceSymbol}reserve${colon}0x00\n\n";
	}
	close SCAT_NAME;
}

#****************************************************************************************
# subroutine:  GenMBRFile
# return:
#****************************************************************************************
sub GenMBRFile
{
	my $iter = 0;
	my $iter_p = 0;
# MBR & EBR table init
#
#	MBR
#			P1: extend partition, include SECRO & SYS
#			P2:	CACHE
#			P3: DATA
#			P4: VFAT
#	EBR1
#			P5: SECRO
#	EBR2
#			P6: SYS
#
	my $mbr_start;
	my @start_block;
	my @size_block;
	my @ebr_start_block;
	my $ebr_count = 0;
	my $br_folder = "$OUT_PATH";
	my @BR = (
		["$OUT_PATH/MBR", [	[0x00,0x0,0x0],
							[0x00,0x0,0x0],
							[0x00,0x0,0x0],
							[0x00,0x0,0x0]]],
	);

	$ebr_start_block[0] = 0;
    #$sheet = get_sheet($SHEET_NAME,$PartitonBook) ;
	# Fill MBR & EBR table -----------------------------------------------------
	for ($iter=0; $iter<@PARTITION_FIELD; $iter++) {
		if($PARTITION_FIELD[$iter] eq "MBR"){
			$mbr_start = $START_FIELD_Byte[$iter];
			next;
		}
		if($PARTITION_FIELD[$iter] =~ /EBR(\d)/){
			$ebr_start_block[$1] =  ($START_FIELD_Byte[$iter]-$mbr_start)/512;
			$BR[$1][0] = "$OUT_PATH/"."$PARTITION_FIELD[$iter]";
			$BR[$1][1] = [[0,0,0],[0,0,0],[0,0,0],[0,0,0]];
			printf ("%s %d %x\n",$BR[$1][0], $1 ,$ebr_start_block[$1]);
			$ebr_count ++;
			next;
		}
		if($PARTITION_IDX_FIELD[$iter]>0){
		        $start_block[$PARTITION_IDX_FIELD[$iter]] = ($START_FIELD_Byte[$iter]-$mbr_start)/512;
			$size_block[$PARTITION_IDX_FIELD[$iter]] =  $SIZE_FIELD_KB[$iter]*1024/512;
		}
	}

	my $item_s = 0;
	for($iter =0;$iter <=$ebr_count;$iter++){
		for($iter_p=1;$iter_p<@BR_INDEX;$iter_p++){
			if($iter ==0 &&$iter_p == 1){
					$BR[$iter][1][0][0] = 0x5;
					$BR[$iter][1][0][1] = $ebr_start_block[$iter+1]-$ebr_start_block[$iter];
					$BR[$iter][1][0][2] = 0xffffffff;
					$item_s ++;
					next;
			}

			if($iter == $BR_INDEX[$iter_p]){
				print "mbr_$iter p_$iter_p $BR_INDEX[$iter_p] index_$item_s\n";
				$BR[$iter][1][$item_s][0] = 0x83;
				$BR[$iter][1][$item_s][1] = $start_block[$iter_p] - $ebr_start_block[$iter];
				$BR[$iter][1][$item_s][2] = $size_block[$iter_p];
				if($iter_p == (@BR_INDEX-1)){
					if($ebr_count>0){
						$BR[$iter][1][$item_s][2] = 0xffffffff-($start_block[$iter_p]-$ebr_start_block[1]);}
					else{
						$BR[$iter][1][$item_s][2] = 0xffffffff;
					}
					last;
				}
				$item_s ++;
				if($item_s == 3){
					if($iter != 0){
						$BR[$iter][1][$item_s][0] = 0x5;
						$BR[$iter][1][$item_s][1] = $ebr_start_block[$iter+1]-$ebr_start_block[1];
						$BR[$iter][1][$item_s][2] = 0xffffffff;
					}else{
						next;
					}
				}
			}
		}
				$item_s=0;
	}
	for($iter_p=1;$iter_p<@BR_INDEX;$iter_p++){
		if($iter_p == 1){
				next;
			}
		printf ("p%d start_block %x size_block %x\n",$iter_p,$start_block[$iter_p],$size_block[$iter_p]);
	}
	for($iter =0;$iter <= $ebr_count;$iter++){
		print "\n$BR[$iter][0] ";
		for($iter_p=0;$iter_p<4;$iter_p++){
			printf("%x ",$BR[$iter][1][$iter_p][0]);
			printf("%x ",$BR[$iter][1][$iter_p][1]);
			printf("%x ",$BR[$iter][1][$iter_p][2]);
		}
	}
	print "\n";

	# Generate MBR&EBR binary file -----------------------------------------------------
	foreach my $sBR (@BR){
		print("Generate $sBR->[0] bin file\n");

		#create file
		open(FH,">$sBR->[0]")|| die "create $sBR->[0] file failed\n";
		print FH pack("C512",0x0);

		#seek to tabel
		seek(FH,446,0);

		foreach (@{$sBR->[1]}){
			#type
			seek(FH,4,1);
			print FH pack("C1",$_->[0]);
			#offset and length
			seek(FH,3,1);
			print FH pack("I1",$_->[1]);
			print FH pack("I1",$_->[2]);
		}

		#end label
		seek(FH,510,0);
		print FH pack("C2",0x55,0xAA);

		close(FH);
	}
}

#****************************************************************************************
# subroutine:  GenPartSizeFile;
# return:
#****************************************************************************************
sub GenPartSizeFile
{
	my $part_size_fh = open_for_rw($PART_SIZE_LOCATION);
	my $Total_Size=512*1024*1024; #Hard Code 512MB for 4+2 project FIX ME!!!!!
	my $temp;
	my $index=0;
	my $vol_size;
	my $min_ubi_vol_size;
	my %PSalias=(
		SEC_RO=>SECRO,
		ANDROID=>SYSTEM,
		USRDATA=>USERDATA,
	);
	my %ubialias=(
		SEC_RO=>SECRO,
		ANDROID=>SYSTEM,
		USRDATA=>USERDATA,
	);
	my $PEB;
	my $LEB;
	my $IOSIZE;

	for($index=0;$index < $total_rows;$index++){
		$Total_Size-=$SIZE_FIELD_KB[$index]*1024;
	}
	$Total_Size -= $PEB*2; #PMT need 2 block	
	for($index=0;$index < $total_rows;$index++){
		if($TYPE_FIELD[$index] eq "EXT4" || $TYPE_FIELD[$index] eq "FAT"){
			$temp = $SIZE_FIELD_KB[$index]*1024;
			if($PARTITION_FIELD[$index] eq "USRDATA"){
				$temp -=1024*1024;
			}
			if(exists($PSalias{$PARTITION_FIELD[$index]})){
				print $part_size_fh "BOARD_$PSalias{$PARTITION_FIELD[$index]}IMAGE_PARTITION_SIZE:=$temp\n" ;
			}else{
				print $part_size_fh "BOARD_$PARTITION_FIELD[$index]IMAGE_PARTITION_SIZE:=$temp\n" ;
			}
		}
	
	}

 	#print $part_size_fh "endif \n" ;
    close $part_size_fh ;
}

#****************************************************************************
# subroutine:  copyright_file_header_for_c
# return:      file header -- copyright
#****************************************************************************
sub copyright_file_header_for_c()
{
    my $template = <<"__TEMPLATE";
/* Copyright Statement:
 *
 * This software/firmware and related documentation ("MediaTek Software") are
 * protected under relevant copyright laws. The information contained herein
 * is confidential and proprietary to MediaTek Inc. and/or its licensors.
 * Without the prior written permission of MediaTek inc. and/or its licensors,
 * any reproduction, modification, use or disclosure of MediaTek Software,
 * and information contained herein, in whole or in part, shall be strictly prohibited.
 */
/* MediaTek Inc. (C) 2012. All rights reserved.
 *
 * BY OPENING THIS FILE, RECEIVER HEREBY UNEQUIVOCALLY ACKNOWLEDGES AND AGREES
 * THAT THE SOFTWARE/FIRMWARE AND ITS DOCUMENTATIONS ("MEDIATEK SOFTWARE")
 * RECEIVED FROM MEDIATEK AND/OR ITS REPRESENTATIVES ARE PROVIDED TO RECEIVER ON
 * AN "AS-IS" BASIS ONLY. MEDIATEK EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE OR NONINFRINGEMENT.
 * NEITHER DOES MEDIATEK PROVIDE ANY WARRANTY WHATSOEVER WITH RESPECT TO THE
 * SOFTWARE OF ANY THIRD PARTY WHICH MAY BE USED BY, INCORPORATED IN, OR
 * SUPPLIED WITH THE MEDIATEK SOFTWARE, AND RECEIVER AGREES TO LOOK ONLY TO SUCH
 * THIRD PARTY FOR ANY WARRANTY CLAIM RELATING THERETO. RECEIVER EXPRESSLY ACKNOWLEDGES
 * THAT IT IS RECEIVER'S SOLE RESPONSIBILITY TO OBTAIN FROM ANY THIRD PARTY ALL PROPER LICENSES
 * CONTAINED IN MEDIATEK SOFTWARE. MEDIATEK SHALL ALSO NOT BE RESPONSIBLE FOR ANY MEDIATEK
 * SOFTWARE RELEASES MADE TO RECEIVER'S SPECIFICATION OR TO CONFORM TO A PARTICULAR
 * STANDARD OR OPEN FORUM. RECEIVER'S SOLE AND EXCLUSIVE REMEDY AND MEDIATEK'S ENTIRE AND
 * CUMULATIVE LIABILITY WITH RESPECT TO THE MEDIATEK SOFTWARE RELEASED HEREUNDER WILL BE,
 * AT MEDIATEK'S OPTION, TO REVISE OR REPLACE THE MEDIATEK SOFTWARE AT ISSUE,
 * OR REFUND ANY SOFTWARE LICENSE FEES OR SERVICE CHARGE PAID BY RECEIVER TO
 * MEDIATEK FOR SUCH MEDIATEK SOFTWARE AT ISSUE.
 *
 * The following software/firmware and/or related documentation ("MediaTek Software")
 * have been modified by MediaTek Inc. All revisions are subject to any receiver's
 * applicable license agreements with MediaTek Inc.
 */
__TEMPLATE

   return $template;
}

#****************************************************************************
# subroutine:  copyright_file_header_for_shell
# return:      file header -- copyright
#****************************************************************************
sub copyright_file_header_for_shell()
{
    my $template = <<"__TEMPLATE";
 # Copyright Statement:
 #
 # This software/firmware and related documentation ("MediaTek Software") are
 # protected under relevant copyright laws. The information contained herein
 # is confidential and proprietary to MediaTek Inc. and/or its licensors.
 # Without the prior written permission of MediaTek inc. and/or its licensors,
 # any reproduction, modification, use or disclosure of MediaTek Software,
 # and information contained herein, in whole or in part, shall be strictly prohibited.
 #
 # MediaTek Inc. (C) 2012. All rights reserved.
 #
 # BY OPENING THIS FILE, RECEIVER HEREBY UNEQUIVOCALLY ACKNOWLEDGES AND AGREES
 # THAT THE SOFTWARE/FIRMWARE AND ITS DOCUMENTATIONS ("MEDIATEK SOFTWARE")
 # RECEIVED FROM MEDIATEK AND/OR ITS REPRESENTATIVES ARE PROVIDED TO RECEIVER ON
 # AN "AS-IS" BASIS ONLY. MEDIATEK EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES,
 # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
 # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE OR NONINFRINGEMENT.
 # NEITHER DOES MEDIATEK PROVIDE ANY WARRANTY WHATSOEVER WITH RESPECT TO THE
 # SOFTWARE OF ANY THIRD PARTY WHICH MAY BE USED BY, INCORPORATED IN, OR
 # SUPPLIED WITH THE MEDIATEK SOFTWARE, AND RECEIVER AGREES TO LOOK ONLY TO SUCH
 # THIRD PARTY FOR ANY WARRANTY CLAIM RELATING THERETO. RECEIVER EXPRESSLY ACKNOWLEDGES
 # THAT IT IS RECEIVER'S SOLE RESPONSIBILITY TO OBTAIN FROM ANY THIRD PARTY ALL PROPER LICENSES
 # CONTAINED IN MEDIATEK SOFTWARE. MEDIATEK SHALL ALSO NOT BE RESPONSIBLE FOR ANY MEDIATEK
 # SOFTWARE RELEASES MADE TO RECEIVER'S SPECIFICATION OR TO CONFORM TO A PARTICULAR
 # STANDARD OR OPEN FORUM. RECEIVER'S SOLE AND EXCLUSIVE REMEDY AND MEDIATEK'S ENTIRE AND
 # CUMULATIVE LIABILITY WITH RESPECT TO THE MEDIATEK SOFTWARE RELEASED HEREUNDER WILL BE,
 # AT MEDIATEK'S OPTION, TO REVISE OR REPLACE THE MEDIATEK SOFTWARE AT ISSUE,
 # OR REFUND ANY SOFTWARE LICENSE FEES OR SERVICE CHARGE PAID BY RECEIVER TO
 # MEDIATEK FOR SUCH MEDIATEK SOFTWARE AT ISSUE.
 #
 # The following software/firmware and/or related documentation ("MediaTek Software")
 # have been modified by MediaTek Inc. All revisions are subject to any receiver's
 # applicable license agreements with MediaTek Inc.
 #/
__TEMPLATE

   return $template;
}



#****************************************************************************************
# subroutine:  get_sheet
# return:      Excel worksheet no matter it's in merge area or not, and in windows or not
# input:       Specified Excel Sheetname
#****************************************************************************************
sub get_sheet {
  my ($sheetName,$Book) = @_;
#	print "get_sheet==>$sheetName";	
#	print "get_sheet==>$Book";	
  return $Book->Worksheet($sheetName);
}

#****************************************************************************************
# subroutine:  get_partition_sheet
# return:      Excel worksheet no matter it's in merge area or not, and in windows or not
# input:       Specified Excel Sheetname
# input:       Excel filename
#****************************************************************************************
sub get_partition_sheet {
	my ($sheetName, $fileName) = @_;
	my $parser = Spreadsheet::ParseExcel->new();
	my $workbook = $parser->Parse($fileName);
	PrintDependency($fileName);
	my $sheet;
	
	if(!defined $workbook) {
		#print "get workbook from $fileName failed, error: ", $parser->error, ".\n";
		return undef;
	} else {
		$sheet = get_sheet($sheetName, $workbook);
		if(!defined $sheet) {
			#print "get $sheetName sheet failed.\n";
			return undef;
		}
		return $sheet;
	}
}

#****************************************************************************************
# subroutine:  load_partition_info
# return:      Excel worksheet no matter it's in merge area or not, and in windows or not
# input:       Specified Excel Sheetname
#****************************************************************************************
sub load_partition_info {
	my ($sheetName) = @_;
	my $sheet;

	#print "load_partition_info==>$sheetName";	
	if (exists $ENV{PTGEN_XLS})
    {
        $PROJECT_PART_TABLE_FILENAME=$ENV{PTGEN_XLS};
	} 
	else
	{
		my $dir1 = 'device';
		my @arrayOfFirstLevelDirs;
		my $SearchFile = 'partition_table_MT6582.xls'; #Search File Name  

		opendir(DIR, $dir1) or die $!;
		#Search First Level path of the dir and save dirs in this path to @arrayOfFirstLevelDirs
		while (my $file = readdir(DIR)) {
		# A file test to check that it is a directory
		next unless (-d "$dir1/$file");
		next unless ( $file !~ m/^\./); #ignore dir prefixed with .
		push @arrayOfFirstLevelDirs, "$dir1/$file";
		}
		closedir(DIR);
		foreach $i (@arrayOfFirstLevelDirs)
		{
		#search folder list+{project}/partition_table_MT6582.xls existence
		$PROJECT_PART_TABLE_FILENAME = $i."\/".$PROJECT."\/".$SearchFile;
		if( -e $PROJECT_PART_TABLE_FILENAME)
		{
		print "Find: $PROJECT_PART_TABLE_FILENAME \n";
		last;
		}
		}

		foreach $i (@arrayOfFirstLevelDirs)
		{
		#search folder list+{baseproject}/partition_table_MT6582.xls existence
		$BASEPROJECT_PART_TABLE_FILENAME = $i."\/".$BASEPROJECT."\/".$SearchFile;
		if( -e $BASEPROJECT_PART_TABLE_FILENAME)
		{
		print "Find: $BASEPROJECT_PART_TABLE_FILENAME \n";
		last;
		}
		}
	}

	# get from project path
	$sheet = get_partition_sheet($sheetName, $PROJECT_PART_TABLE_FILENAME);
	if(!defined $sheet) {
		#print "get partition sheet from $PROJECT_PART_TABLE_FILENAME failed, try $BASEPROJECT_PART_TABLE_FILENAME...\n";
		$sheet = get_partition_sheet($sheetName, $BASEPROJECT_PART_TABLE_FILENAME);
		if(!defined $sheet) {
			#print "get partition sheet from $BASEPROJECT_PART_TABLE_FILENAME failed, try $PART_TABLE_FILENAME...\n";
			# get from default platform path
			$sheet = get_partition_sheet($sheetName, $PART_TABLE_FILENAME);
			if(!defined $sheet) {
				my $error_msg = "Ptgen CAN NOT find sheet=$SHEET_NAME in $PART_TABLE_FILENAME\n";
				print $error_msg;
				die $error_msg;
			}
		}
	}
	return $sheet;
}


#****************************************************************************************
# subroutine:  xls_cell_value
# return:      Excel cell value no matter it's in merge area or not, and in windows or not
# input:       $Sheet:  Specified Excel Sheet
# input:       $row:    Specified row number
# input:       $col:    Specified column number
#****************************************************************************************
sub xls_cell_value {
	my ($Sheet, $row, $col,$SheetName) = @_;
	my $cell = $Sheet->get_cell($row, $col);
	if(defined $cell){
		return  $cell->Value();
  	}else{
		my $error_msg="ERROR in ptgen.pl: (row=$row,col=$col) undefine in $SheetName!\n";
		print $error_msg;
		die $error_msg;
	}
}


sub do_copy_files {
	print $AUTO_CHECK_OUT_FILES;
	if (-e $AUTO_CHECK_OUT_FILES) {
		`rm $AUTO_CHECK_OUT_FILES`;
	}
	open (AUTO_CHECK_OUT_FILES, ">$AUTO_CHECK_OUT_FILES") or &error_handler("Ptgen open $AUTO_CHECK_OUT_FILES Fail!", __FILE__, __LINE__) ;
  
		copy_file("$SCAT_NAME_DIR/*BR*",$COPY_SCATTER_BR_FILES_PATH);
		
		if (-e "$SCAT_NAME_DIR/MT6582_Android_scatter.txt") {
			copy_file("$SCAT_NAME_DIR/MT6582_Android_scatter.txt",$COPY_SCATTER_BR_FILES_PATH);
		}
		if (-e "$SCAT_NAME_DIR/partition_size.mk") {
			copy_file("$SCAT_NAME_DIR/partition_size.mk",$COPY_PATH_PART_SIZE_LOCATION);		
		}	
	

	close(AUTO_CHECK_OUT_FILES);

}

#****************************************************************************
# subroutine:  copy_file
# input:       
#****************************************************************************
sub copy_file()
{
		my ($src_file, $dst_path) = @_;	   
		my $file_name;
		$file_name = substr($src_file, rindex($src_file, "/"),length($src_file));
		if (-e "$dst_path\/$file_name") 
		{
			`chmod 777 $dst_path/$file_name`;	
		}
		else
		{        
				eval { mkpath($dst_path) };
				if ($@)
				{
					&error_handler_2("Can not make dir $dst_path", __FILE__, __LINE__, $@);
				}	   	
		}	   	   	
		`cp $src_file $dst_path `;
		print AUTO_CHECK_OUT_FILES "$dst_path/$file_name\n";
		#print AUTO_CHECK_OUT_FILES "$src_file\n";
}

sub open_for_rw
{
    my $filepath = shift @_;
    if (-e $filepath)
    {
        chmod(0777, $filepath) or &error_handler_2("chmod 0777 $filepath fail", __FILE__, __LINE__);
        if (!unlink $filepath)
        {
            &error_handler("remove $filepath fail ", __FILE__, __LINE__);
        }
    }
    else
    {
        my $dirpath = substr($filepath, 0, rindex($filepath, "/"));
        eval { mkpath($dirpath) };
        if ($@)
        {
            &error_handler_2("Can not make dir $dirpath", __FILE__, __LINE__, $@);
        }
    }
    open my $filehander, "> $filepath" or &error_handler(" Can not open $filepath for read and write", __FILE__, __LINE__);
    push @GeneratedFile, $filepath;
    return $filehander;
}

sub open_for_read
{
    my $filepath = shift @_;
    if (-e $filepath)
    {
        chmod(0777, $filepath) or &error_handler_2("chmod 777 $filepath fail", __FILE__, __LINE__);
    }
    else
    {
        print "No such file : $filepath\n";
        return undef;
    }
    open my $filehander, "< $filepath" or &error_handler_2(" Can not open $filepath for read", __FILE__, __LINE__);
    return $filehander;
}

#****************************************************************************
# subroutine:  error_handler
# input:       $error_msg:     error message
#****************************************************************************
sub error_handler()
{
	   my ($error_msg, $file, $line_no) = @_;
	   my $final_error_msg = "Ptgen ERROR: $error_msg at $file line $line_no\n";
	   print $final_error_msg;
	   die $final_error_msg;
}

sub error_handler_2
{
    my ($error_msg, $file, $line_no, $sys_msg) = @_;
    if (!$sys_msg)
    {
        $sys_msg = $!;
    }
    print "Fatal error: $error_msg <file: $file,line: $line_no> : $sys_msg";
    die;
}
