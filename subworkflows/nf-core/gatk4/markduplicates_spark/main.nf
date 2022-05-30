//
// MARKDUPLICATES AND/OR QC after mapping
//
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run

include { GATK4_ESTIMATELIBRARYCOMPLEXITY        } from '../../../../modules/nf-core/modules/gatk4/estimatelibrarycomplexity/main'
include { GATK4_MARKDUPLICATES_SPARK             } from '../../../../modules/nf-core/modules/gatk4/markduplicatesspark/main'
include { SAMTOOLS_INDEX as INDEX_MARKDUPLICATES } from '../../../../modules/nf-core/modules/samtools/index/main'
include { BAM_TO_CRAM                            } from '../../bam_to_cram'

workflow MARKDUPLICATES_SPARK {
    take:
        bam                           // channel: [mandatory] meta, bam
        dict                          // channel: [mandatory] dict
        fasta                         // channel: [mandatory] fasta
        fasta_fai                     // channel: [mandatory] fasta_fai
        intervals_combined_bed_gz_tbi // channel: [optional]  intervals_bed.gz, intervals_bed.gz.tbi

    main:
    ch_versions = Channel.empty()
    qc_reports  = Channel.empty()

    // Run Markupduplicates spark
    // When running bamqc and/or deeptools output is bam, else cram
    GATK4_MARKDUPLICATES_SPARK(bam, fasta, fasta_fai, dict)
    INDEX_MARKDUPLICATES(GATK4_MARKDUPLICATES_SPARK.out.output)

    bam_bai = GATK4_MARKDUPLICATES_SPARK.out.output
        .join(INDEX_MARKDUPLICATES.out.bai)

    cram_crai = GATK4_MARKDUPLICATES_SPARK.out.output
        .join(INDEX_MARKDUPLICATES.out.crai)

    // Convert Markupduplicates spark bam output to cram when running bamqc and/or deeptools
    BAM_TO_CRAM(bam_bai, Channel.empty(), fasta, fasta_fai, intervals_combined_bed_gz_tbi)

    // Only one of these channel is not empty:
    // - running Markupduplicates spark with bam output
    // - running Markupduplicates spark with cram output
    cram_markduplicates = Channel.empty().mix(
        BAM_TO_CRAM.out.cram_converted,
        cram_crai)

    // When running Marduplicates spark, and saving reports
    GATK4_ESTIMATELIBRARYCOMPLEXITY(bam, fasta, fasta_fai, dict)

    // Other reports done either with BAM_TO_CRAM subworkflow
    // or CRAM_QC subworkflow

    // Gather all reports generated
    qc_reports = qc_reports.mix(GATK4_ESTIMATELIBRARYCOMPLEXITY.out.metrics)

    // Gather versions of all tools used
    ch_versions = ch_versions.mix(GATK4_ESTIMATELIBRARYCOMPLEXITY.out.versions.first())
    ch_versions = ch_versions.mix(GATK4_MARKDUPLICATES_SPARK.out.versions.first())
    ch_versions = ch_versions.mix(INDEX_MARKDUPLICATES.out.versions.first())
    ch_versions = ch_versions.mix(BAM_TO_CRAM.out.versions.first())

    emit:
        cram     = cram_markduplicates
        qc       = qc_reports

        versions = ch_versions // channel: [ versions.yml ]
}