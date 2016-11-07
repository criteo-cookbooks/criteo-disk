Description
===========

Cookbook to manage RAID controller utilities.

This cookbook provides a low-level `volume` resource, that will be
used by a high-level recipe. The recipe will infer sound values for
the resources created according to high-level node attributes.

Requirements
============
## Dependencies

### Cookbooks

*  `parted`
*  `filesystem`

### Ohai

* `filesystem`

## Platforms
* CentOS 6
* CentOS 7

Attributes
==========

* `node['criteo_disk'][#{DEVICE}]['label']` - It's strongly recommanded to use "gpt" label.
* `node['criteo_disk'][#{DEVICE}]['partitions'][#{NAME}]['size']` - Specify the size of the partition NAME. If you want that your partition uses all the disk size, use the wordkey `ALL`
* `node['criteo_disk'][#{DEVICE}]['partitions'][#{NAME}]['file_system']` - Specify the type of filesystem (ex : ext3, ext4 ...)
* `node['criteo_disk'][#{DEVICE}]['partitions'][#{NAME}]['mount_point']` - Specify the mount point to use for the partition
* `node['criteo_disk'][#{DEVICE}]['partitions'][#{NAME}]['mount_options']` - Specify the mount options to use for the partition*
* `node['criteo_disk'][#{DEVICE}]['partitions'][#{NAME}]['mkfs_options']` - Specify the mkfs options to use for the partition*

\* The `default` mkfs_options and mount_options could change depending on the OS and the filesystem.

Recipes
========

The default recipe will create all the partitions declared.

Resources
========
disk
----
The disk resource will set the declared label (if needed) on the disk and call the partition resource for each partition declared.

It takes the following properties :
* device - String containing the disk to interact with
* label - String containing the label to set *
* partitions - Hash containing the partitions to manage on the disk


partition
-------
The partition resource will create the partition passed as property.

By create, we mean :
* Create the partition with the correct name, size and flag.
* Format the partition with the correct filesystem
* Mount the partition on the mount_point with the mount_options
* Update the fstab

It takes the following properties :

* part_name - The name of the partition. It's used as uniq key for a partition. *
* disk - The disk where the partition will be
* size - The size of the partition *
* flag - The flag to set for the partition
* file_system - The file_system to set on the partition *
* mkfs_opts - The options to pass to mkfs command
* mount_opts - The options to pass to mount command
* mount_point - The mount point for the partition

\* A change on these properties will erase the partition.

Limitation
==========

## Partition name
Because of parted cookbook, if you use multiple partition on the same disk, you can't use a partition name that match a part of another partition name on the disk.
### Example
```
DATA2
DATA
```

## Number of partition

On CentOS 6, you can't create more than 1 partition per disk.

In order to create another partition, it needs to reread the partition table.

Since we create,format and mount the partition one by one, the disk is busy when we want to perform the reread.

In the future version, we will change the way to create the partitions.

## mkfs and mount options

The changes on mkfs and mount options are not taking into consideration so far.
These options are only used during the creation.
