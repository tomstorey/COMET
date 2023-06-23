import sys
import re
import json
import copy

def main() -> None:
    """ Process the input file to extract all struct bits and names and
    produce constants for bit position, mask and length.
    """
    try:
        filename = sys.argv[1]
    except IndexError:
        filename = None
    
    if filename is None:
        print('Must specify header filename as argument')
        return

    start_of_union_re = re.compile(r'^typedef union')
    end_of_union_re = re.compile(r'^\} (.+);')
    end_of_want_union_re = re.compile(r'^\} (__(.+)bits_t);')
    start_of_struct_re = re.compile(r'^\s+struct')
    end_of_struct_re = re.compile(r'^\s+}')
    field_bits_re = re.compile(r'^\s+uint(8|16|32)_t (.+)?:(\d+);')
    numbered_field_re = re.compile(r'^([a-zA-Z_]+)(\d*)')
    dependent_reg_re = re.compile(r'^#define (.+?)bits .+volatile __(.+)bits_t')
    asm_def_re = re.compile(r'^#define (\w+?)(bits)? \(\*\(.+(\(.+?\))')

    unions = {}
    union = {}

    with open(filename, 'r') as h:
        in_union = False
        in_struct = False
        pos = 0

        for line in h:
            # See if there is an assembly reg def we can make
            match = asm_def_re.match(line)

            if match:
                if match.groups()[1] is None:
                    def_var = match.groups()[0]
                    def_val = match.groups()[2]

                    print(f'#define {def_var} {def_val}')

            if in_union is False and in_struct is False:
                # Look for a register with struct type
                match = dependent_reg_re.match(line)

                if match:
                    if match[2] in unions:
                        unions[match[2]]['regs'].append(match[1])
                        continue

            # Look for start of a union
            if start_of_union_re.match(line):
                in_union = True
                union = {}
                continue
            
            if in_union is False:
                continue
            
            # Look for end of a union
            match = end_of_union_re.match(line)
            if match:
                # append the current union to the unions dict
                in_union = False

                match = end_of_want_union_re.match(line)
                if match:
                    if match[2] in unions:
                        print(f'Duplicate union detected: __{match[2]}bits_t')
                        return
                    
                    if pos != 0:
                        print(f'A struct in union {match[2]} is improperly populated')

                    unions[match[2]] = union
                    unions[match[2]]['type'] = match[1]
                    unions[match[2]]['regs'] = []

                    # if len(unions) == 4:
                    #     break
                    
                    continue
                
                continue

            # Look for start of a struct
            if start_of_struct_re.match(line):
                in_struct = True
                bits = None
                continue
            
            if in_struct is False:
                continue
            
            # Look for end of a struct
            if end_of_struct_re.match(line):
                in_struct = False
                continue
            
            # Find all struct field bits
            match = field_bits_re.match(line)

            if match:
                if union.get('fields') is None:
                    union['fields'] = {}
                
                length = int(match[3])

                if bits is None:
                    bits = int(match[1])
                    pos = bits

                pos -= length

                if match[2] is None:
                    continue

                if bits == 8:
                    mask = 0xFF >> (8 - length)
                elif bits == 16:
                    mask = 0xFFFF >> (16 - length)
                elif bits == 32:
                    mask = 0xFFFFFFFF >> (32 - length)
                
                union['fields'][match[2]] = {
                    'length': length,
                    'mask': mask,
                    'position': pos
                }

    # Warn of numbered fields that dont have a matching unnumbered field
    for union in unions:
        for field in unions[union]['fields']:
            mask1 = unions[union]['fields'][field]['mask'] << unions[union]['fields'][field]['position']

            match = numbered_field_re.match(field)

            if match[2] in [None, '']:
                continue

            if match[1] in unions[union]['fields']:
                mask2 = unions[union]['fields'][match[1]]['mask'] << unions[union]['fields'][match[1]]['position']

                if mask1 & mask2 != 0:
                    # Numbered field has a matching unnumbered field, and
                    # masks overlap - OK
                    pass
                else:
                    # Numbered field has a matching unnumbered field, but
                    # masks do not overlap
                    print(
                        f'Numbered field {union}.{field} has matching '
                        f'unnumbered field {union}.{match[1]}, but masks do '
                        f'not overlap (0x{mask1:08X} & 0x{mask2:08X} == '
                        f'0x{(mask1 & mask2):08X})'
                    )
            else:
                # Numbered field does not have a matching unnumbered field
                print(
                    f'Numbered field {union}.{field} has no matching '
                    'unnumbered field'
                )
    
    print()

    # Make a temp copy of unions so that unions itself can be modified
    # new_unions = copy.deepcopy(unions)

    # Filter out numbered fields where there is a matching non-numbered field
    # for union in new_unions:
    #     for field in new_unions[union]['fields']:
    #         match = numbered_field_re.match(field)

    #         if match[2] in [None, '']:
    #             continue
            
    #         if match[1] in new_unions[union]['fields']:
    #             # Do masks overlap?
    #             if new_unions[union]['fields'][field]['mask'] & new_unions[union]['fields'][match[1]]['mask'] != 0:
    #                 numbered_mask = (new_unions[union]['fields'][field]['mask'] << new_unions[union]['fields'][field]['position'])
    #                 unnumbered_mask = (new_unions[union]['fields'][match[1]]['mask'] << new_unions[union]['fields'][match[1]]['position'])
    #                 print(f'Delete numbered field {union}.{field} (0x{numbered_mask:08X}) because it overlaps with unnumbered field {union}.{match[1]} (0x{unnumbered_mask:08X})')
    #                 del unions[union]['fields'][field]

    # print(json.dumps(unions, indent=4))

    # Make consts out of parsed info
    for union in unions:
        for reg in unions[union]['regs']:
            fields = [None] * 32

            for field in unions[union]['fields']:
                idx = 31 - unions[union]['fields'][field]['position']

                new_field = unions[union]['fields'][field]
                new_field['name'] = field

                if fields[idx] is None:
                    fields[idx] = new_field
                elif isinstance(fields[idx], list) is False:
                    fields[idx] = [fields[idx], new_field]
                else:
                    fields[idx].append(new_field)

            for field in fields:
                if field is None:
                    continue
                
                if isinstance(field, list) is False:
                    field = [field]

                for item in field:
                    name = item['name']
                    pos = item['position']
                    mask = item['mask']
                    length = item['length']

                    var_pos = f'_{reg}_{name}_POSITION'
                    var_mask = f'_{reg}_{name}_MASK'
                    var_len = f'_{reg}_{name}_LENGTH'

                    print(f'#define {var_pos:50} 0x{pos:08X}')
                    print(f'#define {var_mask:50} 0x{(mask << pos):08X}')
                    print(f'#define {var_len:50} 0x{length:08X}')
                    print()

if __name__ == '__main__':
    main()
