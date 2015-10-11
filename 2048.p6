use Term::termios;

my $saved_termios := Term::termios.new(fd => 1).getattr;
my $termios := Term::termios.new(fd => 1).getattr;
# raw mode interferes with carriage returns, so 
# set flags needed to emulate it manually
$termios.unset_iflags(<BRKINT ICRNL ISTRIP IXON>);
$termios.unset_lflags(<ECHO ICANON IEXTEN ISIG>);
$termios.setattr(:DRAIN);

# reset terminal to original setting on exit
END { $saved_termios.setattr(:NOW) }

my @board = ( ['', '', '', ''] xx 4 );
my $save  = '';
my $score = 0;
my $cell  = 6; # width
my $tab   = "\t\t"; # spacing from left edge
my $top   = join '─' x $cell, '┌', '┬' xx 3, '┐';
my $mid   = join '─' x $cell, '├', '┼' xx 3, '┤';
my $bot   = join '─' x $cell, '└', '┴' xx 3, '┘';

my %dir = (
   (27, 91, 65) => 'up',
   (27, 91, 66) => 'down',
   (27, 91, 67) => 'right',
   (27, 91, 68) => 'left',
);

sub row (@row) { 
    sprintf("│%{$cell}s│%{$cell}s│%{$cell}s│%{$cell}s│\n", @row>>.&center )
}

sub center ($s){
    my $c = $cell - $s.chars;
    my $l = ' ' x floor($c/2);
    my $r = ' ' x ceiling($c/2);
    "$l$s$r";
}

sub clscr {
    if $*DISTRO.is-win {
        run('cls')
    } else {
        run('clear')
    }
}

sub draw-board {
    clscr;
    print "\n\n{$tab}Press direction arrows to move. ";
    print "Press q to quit.\n\n$tab$top\n$tab";
    print join "$tab$mid\n$tab", map { $_.&row }, @board;
    print "$tab$bot\n\n{$tab}Score: ";
}

sub squish (@c) { grep { $_.chars }, @c }

sub prefix:<2x>($v is rw) { $v += $v; $score += $v }

sub prefix:<؟>($v is rw) { $v = '' }

multi sub move('up') {
    for 0 .. 3 -> $y {
        my @col = squish @board[*]>>[$y];
        @col.append: '' xx 4;
        for 0 .. 2 -> $x {
            if @col[$x] && @col[$x+1] == @col[$x] { 2x@col[$x]; ؟@col[$x+1] }
        }
        @col = squish @col;
        @board[$_][$y] = @col[$_] || '' for 0 .. 3; 
    }
}

multi sub move('down') {
    for 0 .. 3 -> $y {
        my @col = squish @board[*]>>[$y];
        for 3 ... 1 -> $x {
            if @col[$x] && @col[$x-1] == @col[$x] { 2x@col[$x]; ؟@col[$x-1] }
        }
        @col = squish @col;
        @col.unshift: '' while @col.elems < 4;
        @board[$_][$y] = @col[$_] for 0 .. 3; 
    }
}

multi sub move('left') {
    for 0 .. 3 -> $y {
        my @row = squish flat @board[$y]>>[*];
        @row.append: '' xx 4;
        for 0 .. 2 -> $x {
            if @row[$x] && @row[$x+1] == @row[$x] { 2x@row[$x]; ؟@row[$x+1] }
        }
        @row = squish @row;
        @board[$y][$_] = @row[$_] || '' for 0 .. 3; 
    }
}

multi sub move('right') {
    for 0 .. 3 -> $y {
        my @row = squish flat @board[$y]>>[*];
        for 3 ... 1 -> $x {
            if @row[$x] && @row[$x-1] == @row[$x] { 2x@row[$x]; ؟@row[$x-1] }
        }
        @row = squish @row;
        @row.unshift: '' while @row.elems < 4;
        @board[$y][$_] = @row[$_] for 0 .. 3; 
    }
}

sub another {
    my @empty;
    for @board.kv -> $r, @row {
        @empty.push(($r, $_)) for grep-index( '', @row);
    }
    my ($x,$y) = @empty.roll;
    @board[$x][$y] = (2,2,2,2,4).roll;
}

loop {
   another() if (join '|', flat @board>>.list) ne $save;
   draw-board();
   say $score;
   # Read up to 4 bytes from keyboard buffer. 
   # Page navigation keys are 3-4 bytes each.
   # Specifically, arrow keys are 3.
   my $get-chr = $*IN.read(4).decode>>.ords;
   $save = join '|', flat @board>>.list;
   move(%dir{$get-chr}) if so %dir{$get-chr};
   last if $get-chr eq 113; # (q)uit
}



