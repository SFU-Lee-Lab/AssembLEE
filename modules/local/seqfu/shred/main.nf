// Copyright (c) the nf-core community under an open-source MIT license.
// See https://github.com/nf-core/modules for full license, file patching instructions and upstream contributing.

process SEQFU_SHRED {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'docker://jimmyliu1326/seqfu2:1.29.0'
        : 'jimmyliu1326/seqfu2:1.29.0'}"

    input:
    // stats can get one or more fasta or fastq files
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("*.gz"), emit: shred
    tuple val("${task.process}"), val('seqfu'), emit: versions_seqfu

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqfu \\
        shred \\
        -t ${task.cpus} \\
        ${args} \\
        ${files} > ${prefix}.fasta
    
    gzip -n ${prefix}.fasta
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}.fasta
    """
}