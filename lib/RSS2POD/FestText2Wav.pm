package RSS2POD::FestText2Wav;
use strict;
use warnings;
use POSIX qw(:termios_h);
use IO::Socket;
use Sys::Syslog qw(:standard);

use vars qw($VERSION);
my $VERSION = "0.001";

sub new {
	my $pkg = shift;
	my $self = 	{
			"voice"  => "voice_kal_diphone",
			"rate"   => 1,
			"volume" => 1,
			"pitch"  => 50,
			"lang"   => "en",
			@_
		};

#openlog("FestText2Wav", "pid,perror,nofatal", "local0");#Jast for module testing
	return bless $self, $pkg;
}

sub festival_connect {
	my $self = shift;
	if ( $self->{handle} ) {
		return 1 if $self->{handle}->connected();
	}
	$self->{host} = shift || "127.0.0.1";
	$self->{port} = shift || 1314;

	$self->{handle} = IO::Socket::INET->new(
		Proto    => "tcp",
		PeerAddr => $self->{host},
		PeerPort => $self->{port}
	);
	if ( !( defined $self->{handle} ) || !$self->{handle} ) {
		syslog(
			"err",
			"Can't connect to FESTIVAL  port $self->{port} on $self->{host}: %m
  				(Are you sure the server is running and accepting connections?)"
		);
	}
	return $self->{handle};
}

sub festival {
	my $self = shift;
	my $arg  = shift;
	$self->{'handle'}->print("$arg\n");
}

sub voice {
	my $self  = shift;
	my $voice = shift;
	$self->{voice} = $voice if $voice;
	syslog( "info", "voice changed to " . $self->{voice} );
	return $self->{voice};
}

sub text2wave_festival {
	my $self = shift;
	my $text = shift;

	#my $out  = shift;
	my $rep = shift;
	$rep = " " unless $rep;

	my ( $host, $port, $kidpid, $handle, $line, $remains, $result );

	my $wave_type      = "riff";            # the type of the audio files
	my $file_stuff_key = "ft_StUfF_key";    # defined in speech tools

	# tell the server to send us back a 'file' of the right type
	$self->festival("(Parameter.set 'Wavefiletype '$wave_type)");

	# split the program into two processes, identical twins
	if ( !defined( $kidpid = fork() ) ) {
		syslog( "err", "can't fork %m" );
		die;
	}
	my $audio_data = '';

	# the if{} block runs only in the parent process
	if ($kidpid) {

		# the parent handles the input so it can exit on quit
		undef $line;
		while ( ( $line = $remains )
			|| defined( $line = $self->{handle}->getline() ) )
		{
			undef $remains;
			if ( $line eq "WV\n" ) {    # we have a waveform coming
				undef $result;
				while ( $line = $self->{handle}->getline() ) {
					if ( $line =~ s/$file_stuff_key(.*)$//s ) {
						$remains = $1;
						$audio_data .= $line;
						last;
					}
					$audio_data .= $line;
				}
				last;
			}
		}
		my $killed = kill( "TERM" => $kidpid );    # send SIGTERM to child
		if ( $killed == 0 ) {
			syslog( "info", "can't keel fork %m" );
		}
		syslog( "info", "Stop voicefy text" );
		return $audio_data;
	}
	else {

		$text =~ s/[\n\r"]/$rep/g;
		syslog( 'info', "Try to voicefy text: $text" );
		$self->festival(
			"(let ((utt (Utterance Text \"$text\")))  
		(begin ($self->{voice}) (Parameter.set 'Duration_Stretch $self->{rate})  
		(utt.synth utt) (utt.wave.resample utt 16000) (utt.wave.rescale utt $self->{volume})  (utt.send.wave.client utt)))"
		);

		#print "End of cheeld process\n";
		sleep 1000000;
	}
}

sub text2wave_festival_threads {
	my $self = shift;
	my $text = shift;

	#my $out  = shift;
	my $rep = shift;
	$rep = " " unless $rep;

	my ( $host, $port, $kidpid, $handle, $line, $remains, $result );

	my $wave_type      = "riff";            # the type of the audio files
	my $file_stuff_key = "ft_StUfF_key";    # defined in speech tools

	# tell the server to send us back a 'file' of the right type
	$self->festival("(Parameter.set 'Wavefiletype '$wave_type)");

	$text =~ s/[\n\r"]/$rep/g;
	syslog( 'info', "Try to voicefy text: $text" );
	$self->festival(
		"(let ((utt (Utterance Text \"$text\")))  
		(begin ($self->{voice}) (Parameter.set 'Duration_Stretch $self->{rate})  
		(utt.synth utt) (utt.wave.resample utt 16000) (utt.wave.rescale utt $self->{volume})  (utt.send.wave.client utt)))"
	);
	syslog( 'info', "Send text to voicefication" );

	my $audio_data = '';

	# the if{} block runs only in the parent process
	#if ($kidpid) {
	# the parent handles the input so it can exit on quit
	undef $line;
	while ( ( $line = $remains )
		|| defined( $line = $self->{handle}->getline() ) )
	{
		undef $remains;
		if ( $line eq "WV\n" ) {    # we have a waveform coming
			undef $result;
			while ( $line = $self->{handle}->getline() ) {
				if ( $line =~ s/$file_stuff_key(.*)$//s ) {
					$remains = $1;
					$audio_data .= $line;
					last;
				}
				$audio_data .= $line;
			}
			last;
		}
	}
	
	syslog( "info", "Stop voicefy text" );
	return $audio_data;

	#my $ret_audio = $get_thread->join();
	#return $ret_audio;
}

=head3
Close connection with festival server
=cut

sub close_connection() {
	my ($self) = @_;
	$self->{handle}->shutdown(2);
}

1;
