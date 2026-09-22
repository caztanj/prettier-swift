#ifndef PRETTIER_H
#define PRETTIER_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct prettier_options prettier_options_t;

prettier_options_t *prettier_options_create(void);
void prettier_options_destroy(prettier_options_t *options);

void prettier_options_set_print_width(prettier_options_t *options, int width);
void prettier_options_set_tab_width(prettier_options_t *options, int width);
void prettier_options_set_use_tabs(prettier_options_t *options, bool use_tabs);
void prettier_options_set_semi(prettier_options_t *options, bool semi);
void prettier_options_set_single_quote(prettier_options_t *options, bool single_quote);
void prettier_options_set_bracket_spacing(prettier_options_t *options, bool bracket_spacing);

char *prettier_format_simple(
    const char *source,
    const char *filepath,
    const char *parser
);

char *prettier_format(
    const char *source,
    const char *filepath,
    const char *parser,
    const prettier_options_t *options,
    char **error_out
);

int prettier_check(
    const char *source,
    const char *filepath,
    const char *parser,
    const prettier_options_t *options,
    char **error_out
);

void prettier_free_string(char *str);

#ifdef __cplusplus
}
#endif

#endif
