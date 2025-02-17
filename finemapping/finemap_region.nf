#!/usr/bin/env nextflow
nextflow.enable.dsl = 1

/*
 * Authors       :
 *
 *
 *      Scott Hazelhurst
 *      Jean-Tristan Brandenburg
 *
 *  On behalf of the H3ABionet Consortium
 *  2015-2022
 *
 *
 * Description : pipeline to do a finemapping 
 *
 */

def strmem(val){
 return val as nextflow.util.MemoryUnit
}


def getlistchro(listchro){
 newlistchro=[]
 for(x in listchro.split(',')) {
  splx=x.split("-")
  if(splx.size()==2){
   r1=splx[0].toInteger()
   r2=splx[1].toInteger()
   for(chro in r1..r2){
    newlistchro.add(chro.toString())
   }
  }else if(splx.size()==1){
   newlistchro.add(x)
  }else{
    logger("problem with chro argument "+x+" "+listchro)
    System.exit(0)
  }
 }
 return(newlistchro)
}
//---- General definitions --------------------------------------------------//

import java.nio.file.Paths

// Checks if the file exists
checker = { fn ->
   if (fn.exists())
       return fn;
    else
       error("\n\n------\nError in your config\nFile $fn does not exist\n\n---\n")
}
nullfile = [false,"False","false", "FALSE",0,"","0","null",null]
def checkColumnHeader(fname, columns) {
  if (workflow.profile == "awsbatch") return;
  if (fname.toString().contains("s3://")) return;
  if (fname.toString().contains("az://")) return;
  if (nullfile.contains(fname)) return;
  new File(fname).withReader { line = it.readLine().tokenize() }
  problem = false;
  columns.each { col ->
    if (! line.contains(col) & col!='') {
      println "The file <$fname> does not contain the column <$col>";
      problem=true;
    }
    if (problem)
      System.exit(2)
  }
}





def helps = [ 'help' : 'help' ]

allowed_params = ["input_dir","input_pat","output","output_dir","data","covariates", "work_dir", "scripts", "max_forks", "phenotype", "accessKey", "access-key", "secretKey", "secret-key",  "instanceType", "instance-type", "bootStorageSize", "boot-storage-size", "maxInstances", "max-instances", "sharedStorageMount", "shared-storage-mount", "max_plink_cores", "pheno","big_time","thin", "batch", "batch_col" ,"samplesize", "manifest", "region", "AMI", "queue", "strandreport"]
params_bin=["finemap_bin", "paintor_bin","plink_bin", "caviarbf_bin", "gcta_bin"]
params_mf=["chro", "begin_seq", "end_seq", "n_pop","threshold_p", "n_causal_snp"]
params_cojo=["cojo_slct_other", "cojo_top_snps","cojo_slct", "cojo_actual_geno"]
params_filegwas=[ "file_gwas", "head_beta", "head_se", "head_A1", "head_A2", "head_freq", "head_chr", "head_bp", "head_rs", "head_pval", "head_n", "used_pval_z", "prob_cred_set"]
params_paintorcav=["paintor_fileannot", "paintor_listfileannot", "caviarbf_avalue"]
params_memcpu=["gcta_mem_req","plink_mem_req", "other_mem_req","gcta_cpus_req", "fm_cpus_req", "fm_mem_req", "modelsearch_caviarbf_bin","caviar_mem_req", "gcta_opt_multigrm_cor", "gcta_opt_grm_cor"]
param_data=["gwas_cat", "genes_file", "genes_file_ftp"]
param_gccat=["headgc_chr", "headgc_bp", "headgc_bp", "genes_file","genes_file_ftp", "gwas_cat_ftp", "list_pheno"]

allowed_params+=params_mf
allowed_params+=params_cojo
allowed_params+=params_filegwas
allowed_params+=params_bin
allowed_params+=params_memcpu
allowed_params+=param_gccat
allowed_params+=params_paintorcav
allowed_params+=param_data



def params_help = new LinkedHashMap(helps)
filescript=file(workflow.scriptFile)
projectdir="${filescript.getParent()}"
dummy_dir="${projectdir}/../qc/input"


params.queue      = 'batch'
params.work_dir   = "$HOME/h3agwas"
params.input_dir  = "${params.work_dir}/input"
params.output_dir = "${params.work_dir}/output"
params.genes_file=""
params.genes_file_ftp="ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_19/gencode.v19.annotation.gtf.gz"
params.output="finemap"

params.gcta_bin="gcta64"

// paramater
params.n_pop=25000

// params file input
params.head_pval = "P_BOLT_LMM"
params.head_freq = ""
params.head_bp = "BP"
params.head_chr = "CHR"
params.head_rs = "SNP"
params.head_beta="BETA"
params.head_se="SE"
params.head_A1="ALLELE0"
params.head_A2="ALLELE1"
params.head_n=""
params.used_pval_z=0
params.headgc_chr=""
params.headgc_bp=""
params.gwas_cat = ""

params.prob_cred_set=0.95

params.plink_mem_req="6GB"

params.other_mem_req="20GB"

// gcta parameters
params.gcta_mem_req="15GB"
params.gcta_cpus_req = 1

params.fm_cpus_req = 5
params.fm_mem_req = "20G"
params.cojo_slct=1
params.cojo_slct_other=""
params.cojo_actual_geno=0
params.big_time='100h'

params.threshold_p=5*10**-8
params.n_causal_snp=3
params.caviarbf_avalue="0.1,0.2,0.4"
params.caviar_mem_req="40GB"
params.paintor_fileannot=""
params.paintor_listfileannot=""
//params.paintor_annot=""

params.gwas_cat_ftp="http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/gwasCatalog.txt.gz"
params.list_pheno=""



params.finemap_bin="finemap"
params.caviarbf_bin="caviarbf"
params.modelsearch_caviarbf_bin="model_search"
params.paintor_bin="PAINTOR"
params.plink_bin="plink"


params.chro=""
params.begin_seq=""
params.end_seq=""

if(params.begin_seq > params.end_seq){
error('begin_seq > end_seq')
}
if(params.gwas_cat==""){
println('gwas_cat : gwas catalog option not initialise, will be downloaded')
process GwasCatDl{
    label 'R'
    publishDir "${params.output_dir}/gwascat",   mode:'copy'
    output :
       file("${out}_all.csv") into gwascat_ch
       file("${out}*")
    script :
      phenol= (params.list_pheno=="") ? "" : "  --pheno '${params.list_pheno}' "
      out="gwascat_format"
      """
      wget -c ${params.gwas_cat_ftp} --no-check-certificate
      format_gwascat.r --file `basename ${params.gwas_cat_ftp}` $phenol --out $out  --chro ${params.chro}
      """
}
headgc_chr="chrom"
headgc_bp="chromEnd"
}else{
gwascat_ch=Channel.fromPath(params.gwas_cat, checkIfExists:true)
headgc_chr=params.headgc_chr
headgc_bp=params.headgc_bp
//checkColumnHeader(params.gwas_cat, [headgc_chr,headgc_bp])

}
if(params.chro=="" | params.begin_seq=="" | params.end_seq==""){
error('chro, begin_seq or end_seq not initialise')
}



params.each { parm ->
  if (! allowed_params.contains(parm.key)) {
    println "\nUnknown parameter : Check parameter <$parm>\n";
  }
}


bed = Paths.get(params.input_dir,"${params.input_pat}.bed").toString().replaceFirst(/^az:/, "az:/").replaceFirst(/^s3:/, "s3:/")
bim = Paths.get(params.input_dir,"${params.input_pat}.bim").toString().replaceFirst(/^az:/, "az:/").replaceFirst(/^s3:/, "s3:/")
fam = Paths.get(params.input_dir,"${params.input_pat}.fam").toString().replaceFirst(/^az:/, "az:/").replaceFirst(/^s3:/, "s3:/")

raw_src_ch= Channel.create()
Channel
    .from(file(bed),file(bim),file(fam))
    .buffer(size:3)
    .map { a -> [checker(a[0]), checker(a[1]), checker(a[2])] }
    .set { raw_src_ch }


gwas_extract_plk=Channel.create()
plink_subplk=Channel.create()
raw_src_ch.separate( gwas_extract_plk, plink_subplk) { a -> [ a, a] }


gwas_file=Channel.fromPath(params.file_gwas,checkIfExists:true)
// plink 
checkColumnHeader(params.file_gwas, [params.head_beta, params.head_se, params.head_A1,params.head_A2, params.head_freq, params.head_chr, params.head_bp, params.head_rs, params.head_pval, params.head_n])
process ExtractPositionGwas{
  memory params.other_mem_req
  input :
     file(filegwas) from gwas_file
     set file(bed),file(bim),file(fam) from gwas_extract_plk
  output :
    file("${out}.gcta") into gcta_gwas
    file("${out}_finemap.z") into  (finemap_gwas_cond, finemap_gwas_sss)
    file("${out}_caviar.z") into caviarbf_gwas
    file("${out}.paintor") into paintor_gwas
    file("${out}.range") into range_plink
    file("${out}.all") into data_i
    file("${out}.pos") into paintor_gwas_annot
  publishDir "${params.output_dir}/file_format/",  mode:'copy'
  script :
    freq= (params.head_freq=="") ? "":" --freq_header ${params.head_freq} "
    nheader= (params.head_n=="") ? "":" --n_header ${params.head_n}"
    nvalue= (params.n_pop=="") ? "":" --n ${params.n_pop}"
    out=params.chro+"_"+params.begin_seq+"_"+params.end_seq
    bfile=bed.baseName
    """
    fine_extract_sig.py --inp_resgwas $filegwas --chro ${params.chro} --begin ${params.begin_seq}  --end ${params.end_seq} --chro_header ${params.head_chr} --pos_header ${params.head_bp} --beta_header ${params.head_beta} --se_header ${params.head_se} --a1_header ${params.head_A1} --a2_header ${params.head_A2} $freq  --bfile $bfile --rs_header ${params.head_rs} --out_head $out --p_header ${params.head_pval}  $nvalue --min_pval ${params.threshold_p} $nheader --z_pval ${params.used_pval_z}
    """
}


process SubPlink{
  input :
     set file(bed),file(bim),file(fam) from plink_subplk
     file(range) from range_plink
  output :
     set file("${out}.bed"),file("${out}.bim"),file("${out}.fam") into (subplink_ld, subplink_gcta)
  script : 
     plk=bed.baseName
     out=plk+'_sub'
     """
     ${params.plink_bin} -bfile $plk  --keep-allele-order --extract  range  $range --make-bed -out  $out
     """
}

process ComputedLd{
   memory params.other_mem_req
   input : 
      set file(bed),file(bim),file(fam) from subplink_ld
  output :
       file("$outld") into (ld_fmcond, ld_fmsss,ld_caviarbf, ld_paintor)
   script :
    outld=params.chro+"_"+params.begin_seq+"_"+params.end_seq+".ld"
    plk=bed.baseName
    """
     ${params.plink_bin} --r2 square0 yes-really -bfile $plk -out "tmp"
    sed 's/\\t/ /g' tmp.ld | sed 's/nan/0/g' > $outld
    """
}

process ComputedFineMapCond{
  label 'finemapping'
  cpus params.fm_cpus_req
  memory params.fm_mem_req
  input :
    file(ld) from ld_fmcond 
    file(filez) from finemap_gwas_cond
  publishDir "${params.output_dir}/fm_cond",  mode:'copy'
  output :
    file("${out}.snp") into res_fmcond
    set file("${out}.config"), file("${out}.cred"), file("${out}.log_cond")
  script:
  fileconfig="config"
  out=params.chro+"_"+params.begin_seq+"_"+params.end_seq+"_cond" 
  """ 
  echo "z;ld;snp;config;cred;log;n_samples" > $fileconfig
  echo "$filez;$ld;${out}.snp;${out}.config;${out}.cred;${out}.log;${params.n_pop}" >> $fileconfig
  ${params.finemap_bin} --cond --in-files $fileconfig   --log --cond-pvalue ${params.threshold_p}  --n-causal-snps ${params.n_causal_snp}  --prob-cred-set ${params.prob_cred_set}
  """
}

process ComputedFineMapSSS{
  label 'finemapping'
  memory params.fm_mem_req
  cpus params.fm_cpus_req
  input :
    file(ld) from ld_fmsss
    file(filez) from finemap_gwas_sss
  publishDir "${params.output_dir}/fm_sss",  mode:'copy'
  output :
    file("${out}.snp") into res_fmsss
    set file("${out}.config"), file("${out}.cred${params.n_causal_snp}"), file("${out}.log_sss")
  script:
  fileconfig="config"
  out=params.chro+"_"+params.begin_seq+"_"+params.end_seq+"_sss"
  """
  echo "z;ld;snp;config;cred;log;n_samples" > $fileconfig
  echo "$filez;$ld;${out}.snp;${out}.config;${out}.cred;${out}.log;${params.n_pop}" >> $fileconfig
  ${params.finemap_bin} --sss --in-files $fileconfig  --n-threads ${params.fm_cpus_req}  --log --n-causal-snps ${params.n_causal_snp} --prob-cred-set ${params.prob_cred_set}
  """
}

process ComputedCaviarBF{
  memory params.caviar_mem_req
  label 'finemapping'
  input :
    file(filez) from caviarbf_gwas
    file(ld) from ld_caviarbf
  publishDir "${params.output_dir}/caviarbf",  mode:'copy'
  output :
   file("${output}.marginal") into res_caviarbf
   set file("$output"), file("${output}.statistics")
  script :
   output=params.chro+"_"+params.begin_seq+"_"+params.end_seq+"_caviarbf"
   """
   ${params.caviarbf_bin} -z ${filez} -r $ld  -t 0 -a ${params.caviarbf_avalue} -c ${params.n_causal_snp} -o ${output} -n ${params.n_pop}
   nb=`cat ${filez}|wc -l `
   ${params.modelsearch_caviarbf_bin} -i $output -p 0 -o $output -m \$nb 2> ${output}_modelsearch.log
   """
}

NCausalSnp=Channel.from(1..params.n_causal_snp)
baliseannotpaint=0
if(params.paintor_fileannot!=""){
paintor_fileannot=Channel.fromPath(params.paintor_fileannot)
paintor_fileannotplot=Channel.fromPath(params.paintor_fileannot)
baliseannotpaint=1
}else{
 if(params.paintor_listfileannot!=""){
  baliseannotpaint=1
  paintor_listfileannot=Channel.fromPath(params.paintor_listfileannot)
  process paintor_selectannot{
   input :
    file(listinfo) from paintor_listfileannot
    file(list_loc) from paintor_gwas_annot
   publishDir "${params.output_dir}/paintor/annot",  mode:'copy'
   output :
    file(out) into (paintor_fileannot, paintor_fileannotplot, paintor_fileannot2)
   script :
   outtmp="tmp.res"
   out="annotationinfo"
   """
   head -1 $list_loc > $outtmp
   sed '1d' $list_loc |awk '{print "chr"\$0}' >> $outtmp
   annotate_locus_paint.py --input $listinfo  --locus $outtmp --out $out --chr chromosome --pos position
   """
  }
  paintor_listfileannot2=Channel.fromPath(params.paintor_listfileannot)
  process paintor_extractannotname{
    input :
       file(fileannot) from paintor_fileannot2
    output :
       stdout into annotname
    """
    head -1 $fileannot | sed 's/ /,/g' 
    """ 
  }
} else{
paintor_fileannot=file("${dummy_dir}/0")
paintor_fileannotplot=file("${dummy_dir}/0")
annotname=Channel.from("N")
}
}
process ComputedPaintor{
   label 'finemapping'
   memory params.fm_mem_req
   input :
    file(filez) from paintor_gwas
    file(ld) from ld_paintor
    file(fileannot) from paintor_fileannot
    val(annot_name) from annotname
  each ncausal from NCausalSnp
  publishDir "${params.output_dir}/paintor/",  mode:'copy'
  output :
      set file("${output}.results"), file("$BayesFactor") into res_paintor
      file(FileInfo) into infores_paintor
      file("${output}*")
  script :
    output=params.chro+"_"+params.begin_seq+"_"+params.end_seq+"_paintor_$ncausal" 
    DirPaintor=output
    annot=(baliseannotpaint==0) ? "" : " -Gname ${output}_an  -annotations ${annot_name}"
    BayesFactor=output+".BayesFactor"
    FileInfo=output+".info"
    Info="$ncausal;${output}.results;$BayesFactor"
    """
    echo "$Info" > $FileInfo
    echo $output > input.files
    cp $filez $output
    cp $ld $output".ld"
    if [ $fileannot == "0" ]
    then
    paint_annotation.py $fileannot $output  $output".annotations"
    else
    cp $fileannot $output".annotations"
    fi
    ${params.paintor_bin} -input input.files -in ./ -out ./ -Zhead Z -LDname ld -enumerate $ncausal -num_samples  ${params.n_pop} -Lname $BayesFactor $annot
    """
}
res_paintor_ch=res_paintor.collect()
infores_paintor_ch=infores_paintor.collect()


process ComputedCojo{
   label 'gcta'
   memory params.gcta_mem_req
   cpus params.gcta_cpus_req
   input :
     set  file(bed),file(bim),file(fam) from subplink_gcta
     file(filez) from gcta_gwas
   publishDir "${params.output_dir}/cojo_gcta",  mode:'copy'
   output :
     file("${output}.jma.cojo")  into res_cojo
     set file("${output}.cma.cojo"), file("${output}.ldr.cojo"), file("${output}.log")
   script :
    output=params.chro+"_"+params.begin_seq+"_"+params.end_seq+"_cojo"
    plk=bed.baseName
    """ 
    ${params.gcta_bin} --bfile $plk  --cojo-slct --cojo-file $filez --out $output  --cojo-p ${params.threshold_p} --thread-num ${params.gcta_cpus_req}  --diff-freq 0.49
    """

}
if(params.genes_file==""){
process GetGenesInfo{
   memory { strmem(params.other_mem_req) + 1.GB * (task.attempt -1) }
   errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
   maxRetries 10
   output :
      file(out) into genes_file_ch
   publishDir "${params.output_dir}/data/",  mode:'copy'
   script :
     out="gencode.v19.genes"
     """
     wget -c ${params.genes_file_ftp} --no-check-certificate
     zcat `basename ${params.genes_file_ftp}` > file_genes
     change_genes_gencode.py file_genes
     """
}
}else{
genes_file_ch=Channel.fromPath(params.genes_file)
}



process MergeResult{
    label 'R'
    memory params.other_mem_req
    input :
      file(paintor) from res_paintor_ch
      file(infopaintor) from infores_paintor_ch
      file(cojo) from res_cojo
      file(caviarbf) from res_caviarbf
      file(fmsss) from res_fmsss
      file(fmcond) from res_fmcond
      file(datai) from data_i
      file(genes) from  genes_file_ch
      file(gwascat) from gwascat_ch
      file(pfileannot) from paintor_fileannotplot
   publishDir "${params.output_dir}/",  mode:'copy'
    output :
       set file("${out}.pdf"), file("${out}.all.out"), file("${out}.all.out")
    script :
      out=params.output
      infopaint=infopaintor.join(" ")
      //pfileannot= (baliseannotpaint==0) ? "":" --paintor_fileannot $pfileannot "
      pfileannot= " --paintor_fileannot $pfileannot "
      """
       cat $infopaint > infopaint
       echo "sss $fmsss" > infofinemap 
       echo "cond $fmcond" >> infofinemap 
       merge_finemapping_v2.r --out $out --listpaintor  infopaint  --cojo  $cojo --datai  $datai --caviarbf $caviarbf --list_genes $genes  --gwascat $gwascat --headbp_gc ${headgc_bp} --headchr_gc ${headgc_chr}  --listfinemap infofinemap  $pfileannot
      """

}

