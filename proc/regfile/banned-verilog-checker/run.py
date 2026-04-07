import argparse
from banned_verilog import VerilogChecker

failed = False

def print_observer(title, message):
    """Simple observer that prints messages to the terminal."""
    print(message)
    global failed
    failed = True

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Verilog Checker Command Line Tool')
    parser.add_argument(
        '-d', '--directory',
        help='Directory containing Verilog files to check'
    )
    parser.add_argument(
        '-l', '--level',
        type=int,
        choices=[1, 2, 3, 4],
        default=1,
        help='Must be 1, 2, 3, or 4. Check README.md for more details.'
    )
    parser.add_argument(
        '-g', '--show-generate',
        type=lambda x: x.lower() == 't',
        default=False,
        help='Show genvar loops (t/f)'
    )

    args = parser.parse_args()
    checker = VerilogChecker()
    
    checker.add_observer(
        callback=print_observer,
        message_type='all',
        html_friendly=False
    )

    checker.check_verilog(
        directory=args.directory,
        level=args.level,
        show_generate=args.show_generate,
        use_filelist=False
    )

    if not failed:
        print("\033[92mNo instances of banned Verilog found. However, this automated banned Verilog checker may produce false positives and false negatives. Your final Gradescope submission will be checked manually for banned Verilog constructs. Check the appropriate checkpoint document for a list of banned Verilog constructs.\033[0m")

if __name__ == "__main__":
    main()
