package Object::GlobalContainer; # A global singleton object container



# The GlobalContainer is another object container and very similar to Object::Container and Object::Registrar, but
# it supports deep hash storages. It means you can save your data by using a path notation like 'foo/bar/more'.
# And that is not handled as a string, but a hash.
#
# SYNOPSIS
# ========
#
#  use Object::GlobalContainer;
#  
#  my $OC = Object::GlobalContainer->new();
#  
#  $OC->set('abc','123');
#  $OC->set('first/second/third','456');
#  
#  print $OC->get('abc');
#  print $OC->get('first/second/third');
#
#
#  ## per default it works as singleton!
#  use Object::GlobalContainer;
#
#  my $OC1 = Object::GlobalContainer->new();
#  my $OC2 = Object::GlobalContainer->new();
#  
#  $OC1->set('abc','123');
#  print $OC2->get('abc'); ## returns also 123 !
#
#  # to disable singleton behaviour, write:
#  my $OC = Object::GlobalContainer->new( notglobal => 1 );
#
#  # loading a class
#  my $c = $OC->class('classes/database', 'Local::MyDatabaseHandler', foo => 123, bar => 456);
#
#
# singleton
# =========
# As shown in synopsis's example, the default behaviour is to work as singleton, because you usually want to
# share things globaly. Disable that by using the flag 'notglobal' in the constructor.
#
#
# imported function
# =================
#
# The most elegant way to deal with that global container, is to use a local funtion:
#
#  use Object::GlobalContainer 'objcon';
#
#  objcon->set('abc','123');
#  objcon->get('abc');
#
# Here it installs the function 'objcon' locally to access the container. Combined with the default behaviour as
# singleton, it is quite usefull. Please note, the name of the method you can choose by yourself and may be different
# in every class.
#
#  
#
# hash storage
# ============
#
# To be honest, I was not lucky with the plain store other classes provide. What means, to have only one string as identifier.
# Often you have already hash structures and you want to store them, but maybe read them with one simple command and not two.
#
# The classical way, other object container usually work:
#
#  my $data = {
#       foo => {
#                bar => {
#                         more => '123',
#                       }
#              }
#             };
#
#  store->set('some/where',$data);
#
#  print store->get('some/where')->{'foo'}->{'bar'}->{'more'};
#
# Here you had to use the get() plus the hash syntax to access the content. With Object::GlobalContainer it is easier to access
# the content directly:
#
#  print store->get('some/where/foo/bar/more');
#
# Because the used string (path) is realy a path for a hash structure.
#
# delimiter
# =========
# The default delimiter for a path is a slash like in 'a/b/c'. But you can change it, by setting 'delimiter' with the constructor:
#
#  my $OC = Object::GlobalContainer->new( delimiter => '.' );
#  $OC->get('a.b.c');
#
# If using the imported function access method, you can change the delimter via a method call:
#
#  use Object::GlobalContainer 'objcon';
#
#  objcon->delimiter('.');
#  objcon->set('a.b.c','123');
#  objcon->get('a.b.c');
# 
#
# LICENSE
# =======   
# You can redistribute it and/or modify it under the conditions of LGPL.
# 
# AUTHOR
# ======
# Andreas Hernitscheck  ahernit(AT)cpan.org



our $VERSION='0.01';

use strict;
use Moose;
use Class::Inspector;



# Don't use that method! It is not a method but used by perl when
# this class is included to export a function in current namespace.
sub import {
	my $pkg = shift;
	my $exportfunc = shift || 'objcon';
	my $caller = caller;
	
	require Exporter::AutoClean;

  ## prepare the given name '$exportfunc' to return
  ## the singleton object stored in the package.
	my %exports = (
		"$exportfunc" => sub { return $__PACKAGE__::SINGLETON },
	);


	## installs the function $exportfunc in the calling class
	Exporter::AutoClean->export( $caller, %exports );
}




# sets the name of the store area.
# Normaly you do not need to change that.
# Default is 'default'. Do not use reserved keys,
# it uses the name space of the module directly.
has 'storename' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'default',
);


# delimter for a path notation to store values.
has 'delimiter' => (
    is      => 'rw',
    isa     => 'Str',
    default => '/',
);


has 'notglobal' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);




## Moose's constructor replace
sub BUILD {
  my $this=shift;

  if ( !$this->notglobal ){

    ## links to a global store by package name
    ## or define a new.
    $this->{'STORE'} = $__PACKAGE__::STORE || {};

    ## save, if it is new
    $__PACKAGE__::STORE = $this->{'STORE'};

    $__PACKAGE__::SINGLETON = $this;

  }

  # if not global
  $this->{'STORE'}||={};

}



## Adds an object (any value or reference).
## Expects a key and a value.
## The key may be a path with slash delimiter.
## It will be stored as nested hash nodes.
sub set { # void ($key1,$value1,$key2,$value2)
  my $this=shift;
  my $pairs={@_};

  foreach my $key( keys %$pairs ) {

    my $location = $this->_hash_location_by_path( path => $key );

    # stores value to location
    ${ $location } = $pairs->{$key}; 

  }
	
}


# builds a recursive hash reference by given path.
# takes hash values like:
# location = reference to formal hashnode
# path = a path like abc/def/more
sub _hash_location_by_path {
  my $this = shift;
  my $v={@_};
  my $path = $v->{'path'};
  my $exec_last = $v->{'exec_last'};
  my $storename =  $this->storename();
  my $dont_create_undef_entry = $v->{'dont_create_undef_entry'};
  my $location = $v->{'location'} || \$this->{'STORE'}->{ $storename }; # ref to a location
  my $pathlocation;

  my $delim = $this->delimiter();

  my @path = split( /$delim/, $path );
  if (scalar(@path) == 0){ die "path has to less elements" };

  my $first = shift @path; # takes first and shorten path



  if ( scalar( @path ) ){ # more path elements?

    $pathlocation = \${ $location }->{ $first };

    # recursive step down the path
    $pathlocation = $this->_hash_location_by_path(  path     => join($delim,@path), 
                                                    location => $pathlocation, 
                                                    remove => $v->{'remove'},
                                                    exec_last => $exec_last,
                                                    dont_create_undef_entry => $dont_create_undef_entry,
									               );

  }else{ # last path element?

    if ($v->{'remove'}){
      delete ${ $location }->{ $first };
      $dont_create_undef_entry = 1;
    }

    if ($exec_last){
       &$exec_last( location => $location, key => $first );
    }

    ## same line again. it seems to be one too much, but it isnt,
    ## that line creates also an undef value, that exists what 
    ## changes the data. exec subs may work different.
    if ( !$dont_create_undef_entry ){
      $pathlocation = \${ $location }->{ $first };
    }

  }


  return $pathlocation;
}




# returns a value by given key, which can be a path.
sub get { # scalar|reference ($path)
  my $this=shift;
  my $key=shift;

  my $location = $this->_hash_location_by_path( path => $key );

  return ${ $location }; 
}


# deletes an entry by removing it from the hash
sub delete { # void ($path)
  my $this=shift;
  my $path=shift;

  my $location = $this->_hash_location_by_path( path => $path, remove => 1 );



}


# Validates if an entry (key) exists.
sub exists { # $boolean ($path)
  my $this=shift;
  my $path=shift;

  my $ex;

  my $location = $this->_hash_location_by_path( 
    path => $path, 
    dont_create_undef_entry => 1,
    exec_last => sub {

      my $v={@_};
      my $location = $v->{'location'};
      my $key = $v->{'key'};

      $ex = exists ${ $location }->{ $key };

    } # end sub

  );



  return $ex;
}



# Creates an instance of the given class and sets it to the given path.
# it also returns the new object. It is managed as a singleton, what means,
# if there is already an object in the given path, it won't instantiate the
# class again. It will call the constructor of the class with given
# parameters.
# If it is already loaded onto given path, it won't load it again. If you want to
# force a new load, please delete it first or replace it with set().
#
#  my $c = $OC->class('classes/database', 'Local::MyDatabaseHandler', foo => 123, bar => 456);
#
# I think the way Object::Container register classes, by it's own name, is against the
# idea of an object container. Because the getting part should not need to know
# what exactly has been set, to keep the application flexible.
# That is why I am setting it into the given path and not the classname.
#
# If for example dealing with mod_perl and keeping the application in memory, it
# is very nice to go again over that code, but automatically skipping a new instantiation.
#
# Otherwise you would need to build your own complex if/else line.
# 
sub class { # $classobject ($path, $classname, %classparam)
  my $this=shift;
  my $path=shift;
  my $classname = shift or die "no classname given";
  my %param = @_;
 
  ## is class installed?
  if (! Class::Inspector->installed($classname) ){
    die "Class \'$classname\' is not installed on this system or wrong lib path.";
  }

  ## load the class
  if (! Class::Inspector->loaded($classname) ){
    eval("use $classname");

    if ( $@ ){
      die "error loading class \'$classname\' by require: $@";
    }
  }

  ## check if it is already at path, if yes, return that (singleton)
  if ( ref($this->get($path)) eq $classname ){
    return $this->get($path);
  }

  my $instance = $classname->new(%param);
  if ( !$instance ){
    die "error loading class \'$classname\' by calling constructor $!";
  }

  $this->set($path, $instance);


  return $instance;
}



1;


#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

Object::GlobalContainer - A global singleton object container


=head1 SYNOPSIS


 use Object::GlobalContainer;
 
 my $OC = Object::GlobalContainer->new();
 
 $OC->set('abc','123');
 $OC->set('first/second/third','456');
 
 print $OC->get('abc');
 print $OC->get('first/second/third');


 ## per default it works as singleton!
 use Object::GlobalContainer;

 my $OC1 = Object::GlobalContainer->new();
 my $OC2 = Object::GlobalContainer->new();
 
 $OC1->set('abc','123');
 print $OC2->get('abc'); ## returns also 123 !

 # to disable singleton behaviour, write:
 my $OC = Object::GlobalContainer->new( notglobal => 1 );

 # loading a class
 my $c = $OC->class('classes/database', 'Local::MyDatabaseHandler', foo => 123, bar => 456);




=head1 DESCRIPTION

The GlobalContainer is another object container and very similar to Object::Container and Object::Registrar, but
it supports deep hash storages. It means you can save your data by using a path notation like 'foo/bar/more'.
And that is not handled as a string, but a hash.



=head1 REQUIRES

L<Class::Inspector> 

L<Moose> 


=head1 METHODS

=head2 class

 my $classobject = $this->class($path, $classname, %classparam);

Creates an instance of the given class and sets it to the given path.
it also returns the new object. It is managed as a singleton, what means,
if there is already an object in the given path, it won't instantiate the
class again. It will call the constructor of the class with given
parameters.
If it is already loaded onto given path, it won't load it again. If you want to
force a new load, please delete it first or replace it with set().

 my $c = $OC->class('classes/database', 'Local::MyDatabaseHandler', foo => 123, bar => 456);

I think the way Object::Container register classes, by it's own name, is against the
idea of an object container. Because the getting part should not need to know
what exactly has been set, to keep the application flexible.
That is why I am setting it into the given path and not the classname.

If for example dealing with mod_perl and keeping the application in memory, it
is very nice to go again over that code, but automatically skipping a new instantiation.

Otherwise you would need to build your own complex if/else line.



=head2 delete

 $this->delete($path);

deletes an entry by removing it from the hash


=head2 exists

 my $boolean = $this->exists($path);

Validates if an entry (key) exists.


=head2 get

 my $scalar | reference = $this->get($path);

returns a value by given key, which can be a path.



=head2 set

 $this->set($key1, $value1, $key2, $value2);

Adds an object (any value or reference).
Expects a key and a value.
The key may be a path with slash delimiter.
It will be stored as nested hash nodes.



=head1 hash storage


To be honest, I was not lucky with the plain store other classes provide. What means, to have only one string as identifier.
Often you have already hash structures and you want to store them, but maybe read them with one simple command and not two.

The classical way, other object container usually work:

 my $data = {
      foo => {
               bar => {
                        more => '123',
                      }
             }
            };

 store->set('some/where',$data);

 print store->get('some/where')->{'foo'}->{'bar'}->{'more'};

Here you had to use the get() plus the hash syntax to access the content. With Object::GlobalContainer it is easier to access
the content directly:

 print store->get('some/where/foo/bar/more');

Because the used string (path) is realy a path for a hash structure.



=head1 singleton

As shown in synopsis's example, the default behaviour is to work as singleton, because you usually want to
share things globaly. Disable that by using the flag 'notglobal' in the constructor.




=head1 imported function


The most elegant way to deal with that global container, is to use a local funtion:

 use Object::GlobalContainer 'objcon';

 objcon->set('abc','123');
 objcon->get('abc');

Here it installs the function 'objcon' locally to access the container. Combined with the default behaviour as
singleton, it is quite usefull. Please note, the name of the method you can choose by yourself and may be different
in every class.

 



=head1 delimiter

The default delimiter for a path is a slash like in 'a/b/c'. But you can change it, by setting 'delimiter' with the constructor:

 my $OC = Object::GlobalContainer->new( delimiter => '.' );
 $OC->get('a.b.c');

If using the imported function access method, you can change the delimter via a method call:

 use Object::GlobalContainer 'objcon';

 objcon->delimiter('.');
 objcon->set('a.b.c','123');
 objcon->get('a.b.c');




=head1 AUTHOR

Andreas Hernitscheck  ahernit(AT)cpan.org


=head1 LICENSE

You can redistribute it and/or modify it under the conditions of LGPL.



=cut

