// import modules
include { FLYE; FLYE as FLYE_SUBSAMPLE } from '../../modules/nf-core/flye/main.nf'
include { MEDAKA } from '../../modules/nf-core/medaka/main.nf'
include { QUAST } from '../../modules/nf-core/quast/main.nf'
include { RAVEN } from '../../modules/nf-core/raven/main.nf'
include { AUTOCYCLER_SUBSAMPLE } from '../../modules/nf-core/autocycler/subsample/main.nf'
include { MINIASM } from '../../modules/nf-core/miniasm/main.nf'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_PAF } from '../../modules/nf-core/minimap2/align/main.nf'
include { MINIPOLISH } from '../../modules/local/minipolish/main.nf'
include { ANY2FASTA; ANY2FASTA as ANY2FASTA_MINIPOLISH } from '../../modules/nf-core/any2fasta/main.nf'
include { FASTA_CONSENSUS_AUTOCYCLER } from '../../subworkflows/nf-core/fasta_consensus_autocycler/main.nf'
include { DNAAPLER } from '../../modules/local/dnaapler/main.nf'

workflow ASSEMBLY_NANOPORE {
    take: reads
    main:

        // only perform assemblies on samples with >N reads
        ch_asm_reads = reads.filter{ it[1].countFastq() >= params.min_nr_asm }
        
        // run assembly workflow
        ch_FLYE_mode = Channel.of('--nano-hq').first()
        FLYE(ch_asm_reads, ch_FLYE_mode)
        ch_first_asm = FLYE.out.fasta

        // calculate coverage using QUAST
        ch_quast_input = ch_first_asm.join(ch_asm_reads)
        QUAST(
            ch_quast_input,
            [ [], [] ],
            [ [], [] ]
        )

        // parse QUAST tsv
        ch_asm_cov = QUAST.out.tsv.map { meta, tsv ->
                def coverage = tsv.readLines().find {
                    it.startsWith('Avg. coverage depth') 
                }.split('\t')[1].toDouble()
                
                return tuple(meta, coverage)
            }

        // retain reads from samples that meet the minimum coverage threshold
        ch_passed_reads = ch_asm_cov.filter { meta, cov ->
                cov >= params.min_asm_cov
            }
            .join(ch_asm_reads, by:0)
            .map { meta, cov, reads -> 
                tuple(meta, reads)
            }
        
        ch_gsize = QUAST.out.tsv.map { meta, tsv ->
                def gsize = tsv.readLines().find {
                    it.startsWith('Total length (>= 0 bp)') 
                }.split('\t')[1].toDouble()
                
                return tuple(meta, gsize)
            }

        ch_subsample_input = ch_passed_reads.join(ch_gsize, by:0)
            .map { meta, reads, gsize -> 
                tuple(meta, reads, gsize)
            }

        // subsample reads from passed samples
        AUTOCYCLER_SUBSAMPLE(ch_subsample_input)
        ch_subsampled_reads = AUTOCYCLER_SUBSAMPLE.out.subsampled_reads
            .transpose()
            .map { meta, reads ->
                [ [id:meta.id, subsample:reads.getSimpleName()], reads]
            }

        // FLYE assembly on subsampled reads
        FLYE_SUBSAMPLE(ch_subsampled_reads, ch_FLYE_mode)

        // RAVEN assembly on subsampled reads
        RAVEN(ch_subsampled_reads)

        // MINIASM assembly on subsampled reads
        // MINIMAP2_ALIGN_PAF(
        //     ch_subsampled_reads,
        //     [ [], [] ],
        //     false,
        //     false,
        //     false,
        //     false
        // )

        // ch_miniasm_input = ch_subsampled_reads
        //     .join(MINIMAP2_ALIGN_PAF.out.paf, by:0)
        // MINIASM(ch_miniasm_input)
        
        // Polish miniasm assembly with minipolish
        // ch_minipolish_input = ch_subsampled_reads.join(MINIASM.out.gfa, by:0)
        // MINIPOLISH(ch_minipolish_input)
        //ANY2FASTA_MINIPOLISH(MINIPOLISH.out.assembly)

        ch_autocycler_input = FLYE_SUBSAMPLE.out.fasta
            .concat(
                RAVEN.out.fasta//,
                //ANY2FASTA_MINIPOLISH.out.fasta
            )
            .map { meta, fasta ->
                tuple([id:meta.id, single_end: true], fasta)
            }
            .filter {  meta, fasta -> 
                fasta.countFasta() > 0

            }
            .groupTuple(by:0)


        FASTA_CONSENSUS_AUTOCYCLER(
            ch_autocycler_input
        )

        // Run DNAapler to reorientate circular contigs
        DNAAPLER(FASTA_CONSENSUS_AUTOCYCLER.out.consensus_assembly_graph)
        ANY2FASTA(DNAAPLER.out.gfa)

        // run polishing
        ch_medaka_input = ch_asm_reads.join(ANY2FASTA.out.fasta)
        MEDAKA(ch_medaka_input)        
        ch_polished_asm = MEDAKA.out.assembly

    emit: 
        polished_asm = ch_polished_asm
}