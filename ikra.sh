#!/bin/bash
set -xe

# オプション関連ここから
# 大部分は http://dojineko.hateblo.jp/entry/2016/06/30/225113 から引用させていただきました。

# 変数 EX_MATRIX_FILE, REF_SPECIES はここで定義
# if [[ $IF_TEST = true ]]; then でテストモード用の実行が可能

# 今まで$1 = EX_MATRIX_FILEだったのを変更している
# 以降の$1をEX_MATRIX_FILEで置き換える必要がある？(必要なら修正お願いします...)


PROGNAME="$( basename $0 )"

VERSION="v1.2.3"

cat << "EOF" 
    __                       
 __/\ \                      
/\_\ \ \/'\   _ __    __     
\/\ \ \ , <  /\`'__\/'__`\   
 \ \ \ \ \\`\\ \ \//\ \L\.\_ 
  \ \_\ \_\ \_\ \_\\ \__/.\_\
   \/_/\/_/\/_/\/_/ \/__/\/_/
                             
EOF

# Usage
function usage() {
  cat << EOS >&2        
ikra ${VERSION} -RNAseq pipeline centered on Salmon-

Usage: ${PROGNAME} experiment_table.csv species [--test, --fastq, --help, --without-docker, --udocker, --protein-coding] [--threads [VALUE]][--output [VALUE]][--suffix_PE_1 [VALUE]][--suffix_PE_2 [VALUE]]
  args
    1.experiment matrix(csv)
    2.reference(human or mouse)

Options:
  --test  test mode(MAX_SPOT_ID=100000). (dafault : False)
  --fastq use fastq files instead of SRRid. The extension must be foo.fastq.gz (default : False)
  -u, --udocker
  -w, --without-docker
  -pc, --protein-coding use protein coding transcripts instead of comprehensive transcripts. (defalut : True)
  -ct, --comprehensive-transcripts use comprehensive transcripts instead of protein coding transcripts. (default : False) 
  -t, --threads
  -o, --output  output file. (default : output.tsv)  
  -l, --log  log file. (default : ikra.log)
  -s1, --suffix_PE_1    suffix for PE fastq files. (default : _1.fastq.gz)
  -s2, --suffix_PE_2    suffix for PE fastq files. (default : _2.fastq.gz)
  -h, --help    Show usage.
  -v, --version Show version.
  -r, --remove-intermediates Remove intermediate files

Citation :
Hiraoka, Yu, Yamada, Kohki, Kawasaki, Yusuke, Hirose, Haruka, Matsumoto, Yasunari, Ishikawa, Kaito, & Yasumizu, Yoshiaki. (2019, July 27). ikra : RNAseq pipeline centered on Salmon. (Version v1.2). Zenodo. http://doi.org/10.5281/zenodo.3352573

Github repo : https://github.com/yyoshiaki/ikra
EOS
  exit 1
}


# version
function version() {
  cat << EOS >&2
ikra ${VERSION} -RNAseq pipeline centered on Salmon-
EOS
  exit 1
}

# デフォルト値を先に定義しておく
RUNINDOCKER=1
DOCKER=docker
THREADS=1
IF_TEST=false
IF_FASTQ=false
IF_PC=True
SUFFIX_PE_1=_1.fastq.gz
SUFFIX_PE_2=_2.fastq.gz
OUTPUT_FILE=output.tsv
LOG_FILE=ikra.log
IF_REMOVE_INTERMEDIATES=false

# オプションをパース
PARAM=()
for opt in "$@"; do
    case "${opt}" in
        #　モード選択など引数の無いオプションの場合
        '--test' )
            IF_TEST=true; shift
            ;;
        '--fastq' )
            IF_FASTQ=true; shift
            ;;
        '-pc'|'--protein-coding' )
            IF_PC=true; shift
            ;;
        '-ct'|'--comprehensive-transcripts' )
            IF_PC=true; shift
            ;;
        '-u'|'--udocker' )
            DOCKER=udocker; shift
            ;;
        '-w'|'--without-docker' )
            RUNINDOCKER=0; shift
            ;;
        #　引数が任意の場合
        '-t'|'--threads' )
            THREADS=4; shift
            if [[ -n "$1" ]] && [[ ! "$1" =~ ^-+ ]]; then
                THREADS="$1"; shift
            fi
            ;;
        '-s1'|'--suffix_PE_1' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
                echo "$PROGNAME: option requires an argument -- $1" 1>&2
                exit 1
            fi
            SUFFIX_PE_1="$2"
            shift 2
            ;;

        '-s2'|'--suffix_PE_2' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
                echo "$PROGNAME: option requires an argument -- $1" 1>&2
                exit 1
            fi
            SUFFIX_PE_2="$2"
            shift 2
            ;;

        '-o'|'--output' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
                echo "$PROGNAME: option requires an argument -- $1" 1>&2
                exit 1
            fi
              OUTPUT_FILE="$2"
              shift 2
              ;;
        '-l'|'--log' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
                echo "$PROGNAME: option requires an argument -- $1" 1>&2
                exit 1
            fi
              LOG_FILE="$2"
              shift 2
                ;;
        '-h' | '--help' )
            usage
            ;;
        '-v' | '--version' )
            version
            ;;
        '-r' | '--remove' )
            IF_REMOVE_INTERMEDIATES=true ; shift
            ;;
        '--' | '-' )
            shift
            PARAM+=( "$@" )
            break
            ;;
        -* )
            echo "${PROGNAME}: illegal option -- '$( echo $1 | sed 's/^-*//' )'" 1>&2
            exit 1
            ;;
        * )
            if [[ -n "$1" ]] && [[ ! "$1" =~ ^-+ ]]; then
                PARAM+=( "$1" ); shift
            fi
            ;;
    esac
done

# オプション無しの値を使う場合はここで処理する
EX_MATRIX_FILE="${PARAM}"; PARAM=("${PARAM[@]:1}")
REF_SPECIES="${PARAM}"; PARAM=("${PARAM[@]:1}")

[[ -z "${EX_MATRIX_FILE}" ]] && usage
[[ -z "${REF_SPECIES}" ]] && usage

# 規定外のオプションがある場合にはusageを表示
if [[ -n "${PARAM[@]}" ]]; then
    usage
fi


cat << EOS | tee -a ${LOG_FILE}
ikra ${VERSION} -RNAseq pipeline centered on Salmon-

EOS

date >> ${LOG_FILE}
pwd >> ${LOG_FILE}
whoami >> ${LOG_FILE}
uname -n >> ${LOG_FILE}

# 結果を表示(オプションテスト用)
cat << EOS | column -t | tee -a ${LOG_FILE}
EX_MATRIX_FILE ${EX_MATRIX_FILE}
REF_SPECIES ${REF_SPECIES}
RUNINDOCKER ${RUNINDOCKER}
DOCKER ${DOCKER}
THREADS ${THREADS}
IF_TEST ${IF_TEST:-false}
IF_FASTQ ${IF_FASTQ:-false}
IF_PC ${IF_PC:-false}
IF_REMOVE_INTERMEDIATES ${IF_REMOVE_INTERMEDIATES:-false}
OUTPUT_FILE ${OUTPUT_FILE}
LOG_FILE ${LOG_FILE}
EOS

set -u

#　オプション関連ここまで

# 実験テーブル.csv

# 十分大きなものにする。
MAXSIZE=20G
SRA_ROOT=$HOME/ncbi/public/sra

SCRIPT_DIR=$(cd $(dirname $0); pwd)

if [[ $REF_SPECIES = mouse ]]; then
  BASE_REF_TRANSCRIPT=ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M21
  REF_TRANSCRIPT=gencode.vM21.transcripts.fa.gz
  if [ $IF_PC = false ]; then
    REF_TRANSCRIPT=gencode.vM21.transcripts.fa.gz
  else
    REF_TRANSCRIPT=gencode.vM21.pc_transcripts.fa.gz
  fi
  SALMON_INDEX=salmon_index_mouse
#   REF_GTF=gencode.vM21.annotation.gtf.gz
  TX2SYMBOL=gencode.vM21.metadata.MGI.gz

elif [[ $REF_SPECIES = human ]]; then
  BASE_REF_TRANSCRIPT=ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_30
  # REF_TRANSCRIPT=gencode.v30.pc_transcripts.fa.gz

  if [ $IF_PC = false ]; then
    REF_TRANSCRIPT=gencode.v30.transcripts.fa.gz
  else
    REF_TRANSCRIPT=gencode.v30.pc_transcripts.fa.gz
  fi

  SALMON_INDEX=salmon_index_human
#   REF_GTF=gencode.v29.annotation.gtf.gz
  TX2SYMBOL=gencode.v30.metadata.HGNC.gz
else
  echo No reference speice!
  exit
fi

COWSAY=cowsay
# PREFETCH=prefetch
FASTQ_DUMP=fastq-dump
FASTERQ_DUMP=fasterq-dump
FASTQC=fastqc
MULTIQC=multiqc
# TRIMMOMATIC=trimmomatic
TRIMGALORE=trim_galore
SALMON=salmon
RSCRIPT_TXIMPORT=Rscript
WGET=wget
PIGZ=pigz


if [[ "$RUNINDOCKER" -eq "1" ]]; then
  echo "RUNNING IN DOCKER"
  # docker を走らせ終わったらコンテナを削除。(-rm)ホストディレクトリをコンテナにマウントする。(-v)

  if [[ $DOCKER = docker ]]; then
    DRUN="$DOCKER run  -u `id -u`:`id -g` --rm -v $PWD:/home -e HOME=/home --workdir /home "
  elif [[ $DOCKER = udocker ]]; then
    DRUN="$DOCKER run --rm -v $PWD:/home --workdir /home "
  fi

  SCRIPT_DIR=`dirname "$0"`
  #--user=biodocker

  # 危険！
  # chmod 777 .

  COWSAY_IMAGE=docker/whalesay
  # quay.io/biocontainers/sra-tools:2.10.7--pl526haddd2b5_1 had an error.
  # the earlier version may stop during the download.
  SRA_TOOLKIT_IMAGE=quay.io/biocontainers/sra-tools:2.10.7--pl526haddd2b5_0
  FASTQC_IMAGE=biocontainers/fastqc:v0.11.5_cv2
  MULTIQC_IMAGE=maxulysse/multiqc:2.0.0
#   TRIMMOMATIC_IMAGE=fjukstad/trimmomatic
#   TRIMMOMATIC_IMAGR=comics/trimmomatic
  TRIMGALORE_IMAGE=quay.io/biocontainers/trim-galore:0.6.3--0
  SALMON_IMAGE=combinelab/salmon:0.14.0
#   SALMON_IMAGE=fjukstad/salmon
  RSCRIPT_TXIMPORT_IMAGE=fjukstad/tximport
  WGET_IMAGE=fjukstad/tximport
  PIGZ_IMAGE=genevera/docker-pigz

  $DOCKER pull $COWSAY_IMAGE
  $DOCKER pull $SRA_TOOLKIT_IMAGE
  $DOCKER pull $FASTQC_IMAGE
  $DOCKER pull $MULTIQC_IMAGE
  # $DOCKER pull $TRIMMOMATIC_IMAGE
  $DOCKER pull $TRIMGALORE_IMAGE
  $DOCKER pull $SALMON_IMAGE
  $DOCKER pull $RSCRIPT_TXIMPORT_IMAGE
  $DOCKER pull $PIGZ_IMAGE

  COWSAY="$DRUN $COWSAY_IMAGE $COWSAY"
  # PREFETCH="$DRUN -v $PWD:/root/ncbi/public/sra $SRA_TOOLKIT_IMAGE $PREFETCH"
  # FASTQ_DUMP="$DRUN $SRA_TOOLKIT_IMAGE $FASTQ_DUMP"
  FASTQ_DUMP="$FASTQ_DUMP"
#  FASTERQ_DUMP="$DRUN $SRA_TOOLKIT_IMAGE $FASTERQ_DUMP"
  FASTQC="$DRUN $FASTQC_IMAGE $FASTQC" 
  FASTQ_DUMP="$FASTQ_DUMP"
  FASTERQ_DUMP="$FASTERQ_DUMP"
  MULTIQC="$DRUN $MULTIQC_IMAGE $MULTIQC"
#   TRIMMOMATIC="$DRUN $TRIMMOMATIC_IMAGE $TRIMMOMATIC"
  # TRIMMOMATIC="$DRUN $TRIMMOMATIC_IMAGE " # fjukstad/trimmomaticのentrypointのため
  TRIMGALORE="$DRUN $TRIMGALORE_IMAGE $TRIMGALORE"
  SALMON="$DRUN $SALMON_IMAGE $SALMON"
#   SALMON="$DRUN $SALMON_IMAGE"
  RSCRIPT_TXIMPORT="$DRUN $RSCRIPT_TXIMPORT_IMAGE $RSCRIPT_TXIMPORT"
  WGET="$DRUN $WGET_IMAGE $WGET"
  PIGZ="$DRUN $PIGZ_IMAGE"

   # docker run --rm -v $PWD:/data -v $PWD:/root/ncbi/public/sra --workdir /data -it inutano/sra-toolkit bash
else
  echo "RUNNING LOCAL"
fi


# if [ $MAX_SPOT_ID = 0 ]; then
if [ $IF_TEST = true ]; then
  $COWSAY "test mode( MAX_SPOT_ID is set)"
  MAX_SPOT_ID="-X 100000"
else
  MAX_SPOT_ID=""
fi

echo $EX_MATRIX_FILE
cat $EX_MATRIX_FILE

# tximport
if [[  -f "tximport_R.R" ]]; then
  rm tximport_R.R
fi

# # tximport_R.Rを取ってくる。
# cp $SCRIPT_DIR/tximport_R.R ./

# 2019/06/09 devv1.3 tximport_R.Rを埋め込み

cat << 'EOF' > tximport_R.R
#! /usr/bin/Rscript

library(tximport)
library(readr)
library(stringr)

# Rscript tximport_R.R gencode.vM19.metadata.MGI.gz Illumina_PE_SRR.csv output.tsv

args1 = commandArgs(trailingOnly=TRUE)[1]
args2 = commandArgs(trailingOnly=TRUE)[2]
args3 = commandArgs(trailingOnly=TRUE)[3]

tx2knownGene <- read_delim(args1, '\t', col_names = c('TXNAME', 'GENEID'))
exp.table <- read.csv(args2, row.names=NULL)

files.raw <- exp.table[,2]

# files.raw <- c("SE/test/ttt30.fq.gz", "SE/test/ttt2.fq.gz")

files.raw <- gsub(".gz$", "", files.raw)
files.raw <- gsub(".fastq$", "", files.raw)
files.raw <- gsub(".fq$", "", files.raw)

split.vec <- sapply(files.raw, basename)
# print(paste(c("salmon_output_") , split.vec, c("/quant.sf"), sep=''))

# files <- paste(c("salmon_output_") , exp.table[,2], c("/quant.sf"), sep='')
files <- paste(c("salmon_output_") , split.vec, c("/quant.sf"), sep='')
names(files) <- exp.table[,1]

print(files)

# txi.salmon <- tximport(files, type = "salmon", tx2gene = tx2knownGene)
txi.salmon <- tximport(files, type = "salmon", tx2gene = tx2knownGene, countsFromAbundance="scaledTPM")

write.table(txi.salmon$counts, file=args3, sep="\t",col.names=NA,row.names=T,quote=F,append=F)
write.table(exp.table[-c(2,3)], file="designtable.csv",row.names=F,quote=F,append=F)

EOF

if [ $IF_FASTQ = false ]; then
# fastq_dump
for i in `tail -n +2  $EX_MATRIX_FILE | tr -d '\r'`
do
name=`echo $i | cut -d, -f1`
SRR=`echo $i | cut -d, -f2`
LAYOUT=`echo $i | cut -d, -f3`
# ADAPTER=`echo $i | cut -d, -f4`

<<COMMENTOUT

There is no -N|--minSpotId and no -X|--maxSpotId option.
fasterq-dump version 2.9.1 processes always the whole accession,
although it may support partial access in future versions.

ということで条件分岐させる。

COMMENTOUT

# fasterq_dump
  # SE
  if [ $LAYOUT = SE ]; then
    # fastq_dump
    if [[ ! -f "$SRR.fastq.gz" ]]; then
      if [[ $MAX_SPOT_ID == "" ]]; then
        $FASTERQ_DUMP $SRR --threads $THREADS --force -p
        # gzip $SRR.fastq
        $PIGZ $SRR.fastq
      else
        $FASTQ_DUMP $SRR $MAX_SPOT_ID --gzip
      fi
    fi

    # fastqc
    if [[ ! -f "${SRR}_fastqc.zip" ]]; then
      $FASTQC -t $THREADS ${SRR}.fastq.gz
    fi

  # PE
  else
    # fastq_dump
    if [[ ! -f "${SRR}_1.fastq.gz" ]]; then
      if [[ $MAX_SPOT_ID == "" ]]; then
        $FASTERQ_DUMP $SRR --split-files --threads $THREADS --force -p
        # gzip ${SRR}_1.fastq
        # gzip ${SRR}_2.fastq
        $PIGZ ${SRR}_1.fastq
        $PIGZ ${SRR}_2.fastq
      else
        $FASTQ_DUMP $SRR $MAX_SPOT_ID --gzip --split-files
      fi
    fi

    # fastqc
    if [[ ! -f "${SRR}_1_fastqc.zip" ]]; then
      $FASTQC -t $THREADS ${SRR}${SUFFIX_PE_1}
      $FASTQC -t $THREADS ${SRR}${SUFFIX_PE_2}
    fi
  fi
done
fi

if [[ ! -f "multiqc_report_raw_reads.html" ]]; then
  $MULTIQC -n multiqc_report_raw_reads.html .
fi

# determin threads for trim galore.
# the sweet spot for TG is 4
if [ $THREADS -gt 4 ] ; then
  THREADS_TRIMGALORE=4
else
  THREADS_TRIMGALORE=$THREADS
fi


for i in `tail -n +2  $EX_MATRIX_FILE | tr -d '\r'`
do
  if [ $IF_FASTQ = false ]; then
    # fasterq_dump
    name=`echo $i | cut -d, -f1`
    SRR=`echo $i | cut -d, -f2`
    LAYOUT=`echo $i | cut -d, -f3`
    dirname_fq=""
  else
    name=`echo $i | cut -d, -f1`
    fq=`echo $i | cut -d, -f2`
    LAYOUT=`echo $i | cut -d, -f3`
    fqname_ext="${fq##*/}"
    # echo $fqname_ext

    # ファイル名を取り出す（拡張子なし）
    # basename_fq="${fqname_ext%.*.*}"
    basename_fq=${fqname_ext}
    dirname_fq=`dirname $fq`
    dirname_fq=${dirname_fq}/
    SRR=${basename_fq}
  fi


  # trim_galore
  # SE
  if [ $LAYOUT = SE ]; then
    if [  -f "${dirname_fq}${SRR}.fq"] && [ ! -f "${dirname_fq}${SRR}.fastq.gz" ]; then
      $PIGZ ${dirname_fq}${SRR}.fq
      ln -s ${dirname_fq}${SRR}.fq.gz ${dirname_fq}${SRR}.fastq.gz
    fi
    if [ -f "${dirname_fq}${SRR}.fastq" ] && [ ! -f "${dirname_fq}${SRR}.fastq.gz" ]; then
      $PIGZ ${dirname_fq}${SRR}.fastq
    fi
    if [ -f "${dirname_fq}${SRR}.fq.gz" ] && [ ! -f "${dirname_fq}${SRR}.fastq.gz" ]; then
      ln -s ${dirname_fq}${SRR}.fq.gz ${dirname_fq}${SRR}.fastq.gz
    fi

    if [[ ! -f "${dirname_fq}${SRR}_trimmed.fq.gz" ]]; then
      $TRIMGALORE --cores ${THREADS_TRIMGALORE} ${dirname_fq}${SRR}.fastq.gz
    fi

    # fastqc
    if [[ ! -f "${dirname_fq}${SRR}_trimmed_fastqc.zip" ]]; then
      $FASTQC -t $THREADS ${dirname_fq}${SRR}_trimmed.fq.gz
    fi

  # PE
  else
    if [ -f "${dirname_fq}${SRR}_1.fq" ] && [ ! -f "${dirname_fq}${SRR}_1.fastq.gz" ]; then
      ${PIGZ} ${dirname_fq}${SRR}_1.fq
      ${PIGZ} ${dirname_fq}${SRR}_2.fq
      ln -s ${dirname_fq}${SRR}_1.fq.gz ${dirname_fq}${SRR}_1.fastq.gz
      ln -s ${dirname_fq}${SRR}_2.fq.gz ${dirname_fq}${SRR}_2.fastq.gz
    fi
    if [ -f "${dirname_fq}${SRR}_1.fastq" ] && [ ! -f "${dirname_fq}${SRR}_1.fastq.gz" ]; then
      $PIGZ ${dirname_fq}${SRR}_1.fastq
      $PIGZ ${dirname_fq}${SRR}_2.fastq
    fi
    if [  -f "${dirname_fq}${SRR}.fq.gz" ] && [ ! -f "${dirname_fq}${SRR}_1.fastq.gz" ]; then
      ln -s ${dirname_fq}${SRR}.fq.gz ${dirname_fq}${SRR}.fastq.gz
    fi
    if [ -f "${dirname_fq}${SRR}${SUFFIX_PE_1}" ] && [ ! -f "${dirname_fq}${SRR}_1.fastq.gz" ]; then
      ln -s ${dirname_fq}${SRR}${SUFFIX_PE_1} ${dirname_fq}${SRR}_1.fastq.gz
      ln -s ${dirname_fq}${SRR}${SUFFIX_PE_2} ${dirname_fq}${SRR}_2.fastq.gz
    fi

    # trimmomatic
    if [[ ! -f "${dirname_fq}${SRR}_1_val_1.fq.gz" ]]; then
      $TRIMGALORE --cores ${THREADS_TRIMGALORE} \
      --paired ${dirname_fq}${SRR}_1.fastq.gz ${dirname_fq}${SRR}_2.fastq.gz \
      --output_dir ${dirname_fq}
    fi

    # fastqc
    if [[ ! -f "${dirname_fq}${SRR}_1_val_1_fastqc.zip" ]]; then
      $FASTQC -t $THREADS ${dirname_fq}${SRR}_1_val_1.fq.gz
      $FASTQC -t $THREADS ${dirname_fq}${SRR}_2_val_2.fq.gz
    fi
  fi
done

# download $REF_TRANSCRIPT
if [[ ! -f "$REF_TRANSCRIPT" ]]; then
  $WGET $BASE_REF_TRANSCRIPT/$REF_TRANSCRIPT
fi

# # download $REF_GTF
# if [[ ! -f "$REF_GTF" ]]; then
#   wget $BASE_REF_TRANSCRIPT/$REF_GTF
# fi

# instance salmon index
if [[ ! -d "$SALMON_INDEX" ]]; then
  $SALMON index --threads $THREADS --transcripts $REF_TRANSCRIPT --index $SALMON_INDEX --type quasi -k 31 --gencode
fi

for i in `tail -n +2  $EX_MATRIX_FILE | tr -d '\r'`
do
  if [ $IF_FASTQ = false ]; then
    # fasterq_dump
    name=`echo $i | cut -d, -f1`
    SRR=`echo $i | cut -d, -f2`
    LAYOUT=`echo $i | cut -d, -f3`
    dirname_fq=""
  else
    name=`echo $i | cut -d, -f1`
    fq=`echo $i | cut -d, -f2`
    LAYOUT=`echo $i | cut -d, -f3`
    fqname_ext="${fq##*/}"
    # echo $fqname_ext

    # ファイル名を取り出す（拡張子なし）
    # basename_fq="${fqname_ext%.*.*}"
    basename_fq=${fqname_ext}
    dirname_fq=`dirname $fq`
    dirname_fq=${dirname_fq}/
    SRR=${basename_fq}
  fi

  # SE
  if [ $LAYOUT = SE ]; then
    if [[ ! -f "salmon_output_${SRR}/quant.sf" ]]; then
      mkdir salmon_output_${SRR}
      # libtype auto detection mode
      $SALMON quant -i $SALMON_INDEX \
      -l A \
      -r ${dirname_fq}${SRR}_trimmed.fq.gz \
      -p $THREADS \
      -o salmon_output_${SRR} \
      --gcBias \
      --validateMappings
  #       -g $REF_GTF
    fi

   # PE
  else
    if [[ ! -f "salmon_output_${SRR}/quant.sf" ]]; then
      mkdir salmon_output_${SRR}
      # libtype auto detection mode
      $SALMON quant -i $SALMON_INDEX \
      -l A \
      -1 ${dirname_fq}${SRR}_1_val_1.fq.gz \
      -2 ${dirname_fq}${SRR}_2_val_2.fq.gz \
      -p $THREADS \
      -o salmon_output_${SRR} \
      --gcBias \
      --validateMappings
  #       -g $REF_GTF
    fi
  fi
done

# multiqc
if [[ ! -f "multiqc_report.html" ]]; then
  $MULTIQC -n multiqc_report.html .
fi

# download $TX2SYMBOL
if [[ ! -f "$TX2SYMBOL" ]]; then
  $WGET $BASE_REF_TRANSCRIPT/$TX2SYMBOL
fi

# tximport
if [[ ! -f "$OUTPUT_FILE" ]]; then
  $RSCRIPT_TXIMPORT tximport_R.R $TX2SYMBOL $EX_MATRIX_FILE $OUTPUT_FILE
fi

# tximport
if [[  -f "tximport_R.R" ]]; then
  rm tximport_R.R
fi

if [ $IF_REMOVE_INTERMEDIATES = true ]; then
  rm -f *fastq.gz
  rm -f *fq.gz
  rm -f gencode*.gz
  rm -f *fastqc.zip
  rm -rf salmon_output_*
fi
# if [[ "$RUNINDOCKER" -eq "1" ]]; then
#
#   chmod 755 .
#
# fi

cat << EOS | tee -a ${LOG_FILE}
RUN : success!

EOS
