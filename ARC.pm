package Cache::ARC;

our $VERSION = '0.01';
use Exporter;

@ISA = (Exporter);

use strict;
use warnings;
#use List::Util qw(first max maxstr min minstr reduce shuffle sum);
#use Data::Dumper;
no warnings 'experimental::smartmatch';

sub new {
	my $proto = shift;
	my %args = (DATA_FILENAME	=> undef,
				SIZE			=> undef,
				@_);

	my $class = ref($proto) || $proto;
	my $self = bless({}, $class);

	$self->{'c'}			= 1024;
	$self->{'_dataFilename'}= $args{DATA_FILENAME};
	$self->{'_cached'}		= {};
	$self->{'p'}			= 0;
	$self->{'t1'}			= [];
	$self->{'t2'}			= [];
	$self->{'b1'}			= [];
	$self->{'b2'}			= [];

	if($args{SIZE}) {
		$self->{'c'} = $args{SIZE};
	}

	$self->Init();
	
	return $self;
}

sub Init {
	my $self = shift;

	if($self->{'_dataFilename'}) {
		$self->loadData(DATA_FILENAME => $self->{'_dataFilename'});
	}
}

sub getData {
	my $self = shift;
	my %args = (KEY	=> undef,
				@_);

	if($args{KEY} ~~ $self->{t1}) {
		$self->{t1} = [grep $_ ne $args{KEY}, @{$self->{t1}}];
		unshift(@{$self->{t2}}, $args{KEY});
		return($self->{_cached}{$args{KEY}});
	}
	if($args{KEY} ~~ $self->{t2}) {
		$self->{t2} = [grep $_ ne $args{KEY}, @{$self->{t2}}];
		unshift(@{$self->{t2}}, $args{KEY});
		return($self->{_cached}{$args{KEY}});
	}

	return(undef);
}

sub setData {
	my $self = shift;
	my %args = (KEY		=> undef,
				DATA	=> undef,
				@_);
	my $old = undef;

	$self->{_cached}{$args{KEY}} = $args{DATA};
	
	if($args{KEY} ~~ $self->{b1}) {
		$self->{p} = min($self->{c}, $self->{p} + max((@{$self->{b2}} / @{$self->{b1}}), 1));
		$self->replace(KEY => $args{KEY});
		$self->{b1} = [grep $_ ne $args{KEY}, @{$self->{b1}}];
		unshift(@{$self->{t2}}, $args{KEY});
		return($args{DATA});
	}

	if($args{KEY} ~~ $self->{b2}) {
		$self->{p} = max(0, ($self->{p} - max(@{$self->{b1}} / @{$self->{b2}}), 1));
		$self->replace(KEY => $args{KEY});
		$self->{b2} = [grep $_ ne $args{KEY}, @{$self->{b2}}];
		unshift(@{$self->{t2}}, $args{KEY});
		return($args{DATA});
	}

	if((@{$self->{t1}} + @{$self->{b1}}) == $self->{c}) {
		if(@{$self->{t1}} < $self->{c}) {
			pop(@{$self->{b1}});
			$self->replace(KEY => $args{KEY});
		} else {
			delete($self->{_cached}{pop(@{$self->{t1}})});
		}
	} else {
		my $total = @{$self->{t1}} + @{$self->{b1}} + @{$self->{t2}} + @{$self->{b2}};
		if($total >= $self->{c}) {
			if($total == (2 * $self->{c})) {
				pop(@{$self->{b2}});
			}
			$self->replace(KEY => $args{KEY});
		}
	}

	unshift(@{$self->{t1}}, $args{KEY});
	return($args{DATA});
}

sub replace {
	my $self = shift;
	my %args = (KEY	=> undef,
				@_);
	my $old = undef;

	if (@{$self->{t1}} > 0 && (($args{KEY} ~~ @{$self->{b2}} && @{$self->{t1}} == $self->{p}) || (@{$self->{t1}} > $self->{p}))) {
		$old = pop(@{$self->{t1}});
		unshift(@{$self->{b1}}, $old);
	} else {
		$old = pop(@{$self->{t2}});
		unshift(@{$self->{b2}}, $old);
	}
	delete($self->{_cached}{$old});
}

sub delData {
	my $self = shift;
	my %args = (KEY	=> undef,
				@_);

	if($args{KEY} ~~ $self->{t1}) {
		$self->{t1} = [grep $_ ne $args{KEY}, @{$self->{t1}}];
	}
	if($args{KEY} ~~ $self->{t2}) {
		$self->{t2} = [grep $_ ne $args{KEY}, @{$self->{t2}}];
	}
	if($args{KEY} ~~ $self->{b1}) {
		$self->{b1} = [grep $_ ne $args{KEY}, @{$self->{b1}}];
	}
	if($args{KEY} ~~ $self->{b2}) {
		$self->{b2} = [grep $_ ne $args{KEY}, @{$self->{b2}}];
	}
	delete($self->{_cached}{$args{KEY}});
	
	return(1);
}

sub dumpData {
	my $self = shift;
	my %args = (DATA_FILENAME	=> undef,
				@_);
	
	open(FILE, '>', $args{DATA_FILENAME}) or die "Can not open file, $!";
	foreach my $key(keys %{$self->{_cached}}) {
		print FILE "\t'".$key."' => '".$self->{_cached}{$key}."'\n";
	}
	close FILE;
		
	return(1);
}

sub loadData {
	my $self = shift;
	my %args = (DATA_FILENAME	=> undef,
				@_);

	open(my $fh, '<', $args{DATA_FILENAME}) or die "Can not open file, $!";
	while(<$fh>) {
		if($_ =~ m/^\s*\'/) {
			my(@data) = split("' => '", $_);
			$data[0] =~ s/^\t\'//;
			$data[1] =~ s/\'$//;
			chomp($data[1]);
			$self->setData(KEY => $data[0], DATA => $data[1]);
		}
	}
	close $fh;
		
	return(1);
}

sub clear {
	my $self = shift;

	$self->{t1} = [];
	$self->{t2} = [];
	$self->{b1} = [];
	$self->{b2} = [];
	$self->{_cached} = {};
	
	return(1);
}

1;

__END__;

=head1 NAME

Cache::ARC - simple implementation of Adaptive Replacement Cache

=head1 SYNOPSIS

	use Cache::ARC;
	
	my $cache = Cache::ARC->new(DATA_FILENAME => $data_file_name, SIZE => $max_num_of_entries);
	
	$cache->setData(KEY => $key, DATA => $value);
	
	$value = $cache->getData(KEY => $key);
	
	$cache->delData(KEY => $key);
	
	$cache->dumpData(DATA_FILENAME => $data_file_name);
	
	$cache->loadData(DATA_FILENAME => $data_file_name);
	
	$cache->clear();

=head1 DESCRIPTION

Cache::ARC is a simple and fast implementation of an in-memory ARC cache in pure Perl

=head1 FUNCTIONS

=head2 Cache::ARC->new(DATA_FILENAME => $data_file_name, SIZE => $max_num_of_entries)

Creating a new object cache.
Where DATA_FILENAME a file with saved data early work of this module,
SIZE is the dimension (number of rows) cache on umolyaaniyu SIZE = 1024.
These parameters during initialization are not required.
In all other cases, the parameters in the call are mandatory.

=head2 $cache->setData(KEY => $key, DATA => $value)

Save the needed data in the cache.

=head2 $cache->getData(KEY => $key)

The requested content cache on the desired key to us.
	
=head2 $cache->delData(KEY => $key)

Delete the data from the cache on the desired key to us.
	
=head2 $cache->dumpData(DATA_FILENAME => $data_file_name)

Save the data in the cache file for future use.
	
=head2 $cache->loadData(DATA_FILENAME => $data_file_name)

Load cache data for future use.

=head2 $cache->clear()

Complete cleaning of the data from the cache.

=head1 AUTHOR

Sergey I. Avramov

=head1 SEE ALSO

L<Cache>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

See <http://www.perl.com/perl/misc/Artistic.html>

=cut
